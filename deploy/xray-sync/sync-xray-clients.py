#!/usr/bin/env python3
"""
MOROK VPN — синхронизация выданных ключей с ядром Xray (VLESS Reality).

Зачем: бэкенд строит vless://<uuid>@… из AccessKey.uuid, но ядро пускает только
тех, кто лежит в inbound `settings.clients`. Пока список пуст — ключ «выдан», а
туннель не поднимается. Этот скрипт делает клиентов ядра зеркалом того, что
реально активно в базе, и дёргает SIGHUP (Xray перечитывает конфиг, активные
соединения не рвёт).

Откуда берёт желающих: файл /var/lib/morok/xray-clients.json, который пишет
бэкенд (src/provisioning/xray-client-sync.service.ts). Формат:

    { "generatedAt": "…", "clients": [ { "id": "<uuid>", "email": "<keyId>" } ] }

Почему не читаем базу напрямую: бэкенд уже держит единственно верный критерий
«кому можно» (ACTIVE + не протух + активирован), дублировать SQL-логику здесь
значит через полгода иметь два разных ответа на вопрос «кто активен».

Идемпотентен: если набор клиентов совпадает — ни записи, ни рестарта.
Запуск: cron раз в минуту (см. deploy/xray-sync/README) + вручную.
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import time

WANTED = "/var/lib/morok/xray-clients.json"
CONFIG = os.environ.get("XRAY_CONFIG", "/var/lib/marzban/xray_config.json")
INBOUND_TAG = os.environ.get("XRAY_INBOUND_TAG", "VLESS-Reality")
DOCKER_CONTAINER = os.environ.get("XRAY_CONTAINER", "marzban-marzban-1")
STATE = "/var/lib/morok/xray-sync.state"


def load_wanted():
    if not os.path.exists(WANTED):
        return None
    with open(WANTED) as fh:
        doc = json.load(fh)
    clients = doc.get("clients")
    if clients is None:
        return None
    # Нормализуем: Xray требует id (uuid) и произвольный email-ярлык.
    out = []
    for c in clients:
        cid = (c or {}).get("id")
        if not cid:
            continue
        out.append({"id": cid, "email": str(c.get("email") or cid)[:64]})
    return out


def read_config():
    with open(CONFIG) as fh:
        return json.load(fh)


def current_clients(cfg):
    for inb in cfg.get("inbounds", []):
        if inb.get("tag") == INBOUND_TAG or (
            inb.get("port") == 443 and inb.get("protocol") == "vless"
        ):
            return (inb.get("settings") or {}).get("clients") or []
    raise SystemExit(f"inbound {INBOUND_TAG} не найден в {CONFIG}")


def set_clients(cfg, clients):
    for inb in cfg.get("inbounds", []):
        if inb.get("tag") == INBOUND_TAG or (
            inb.get("port") == 443 and inb.get("protocol") == "vless"
        ):
            inb.setdefault("settings", {})["clients"] = clients
            return inb
    raise SystemExit(f"inbound {INBOUND_TAG} не найден в {CONFIG}")


def fingerprint(clients):
    return "|".join(sorted(f"{c['id']}:{c.get('email', '')}" for c in clients))


def reload_xray():
    """SIGHUP главному процессу xray внутри контейнера.

    Пробуем сначала docker kill --signal (не требует, чтобы в контейнере был
    shell), иначе — exec в контейнер.
    """
    try:
        r = subprocess.run(
            ["docker", "kill", "--signal", "HUP", DOCKER_CONTAINER],
            capture_output=True,
            text=True,
            timeout=20,
        )
        if r.returncode == 0:
            return "docker-kill-HUP"
    except Exception:  # noqa: BLE001
        pass
    pid = subprocess.run(
        ["docker", "exec", DOCKER_CONTAINER, "pgrep", "-x", "xray"],
        capture_output=True,
        text=True,
        timeout=20,
    ).stdout.strip().splitlines()
    if not pid:
        raise SystemExit("не нашёл процесс xray внутри контейнера — перезапусти контейнер вручную")
    subprocess.run(
        ["docker", "exec", DOCKER_CONTAINER, "kill", "-HUP", pid[0]],
        capture_output=True,
        timeout=20,
    )
    return "kill-HUP"


def main():
    dry = "--dry-run" in sys.argv
    wanted = load_wanted()
    if wanted is None:
        print(f"нет файла {WANTED} — бэкенд ещё ничего не выдал, ничего не делаю")
        return 0

    cfg = read_config()
    have = current_clients(cfg)
    if fingerprint(have) == fingerprint(wanted):
        with open(STATE, "w") as fh:
            fh.write(json.dumps({"at": time.time(), "clients": len(wanted), "changed": False}))
        print(f"уже синхронно ({len(wanted)} клиентов), ничего не трогаю")
        return 0

    if dry:
        print(f"DRY-RUN: было {len(have)}, станет {len(wanted)}")
        for c in wanted[:5]:
            print("  +", c["id"], c["email"])
        return 0

    backup = f"{CONFIG}.bak"
    shutil.copy2(CONFIG, backup)
    set_clients(cfg, wanted)
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(cfg, fh, indent=2, ensure_ascii=False)
    os.replace(tmp, CONFIG)
    how = reload_xray()
    time.sleep(1.5)
    ok = subprocess.run(
        ["docker", "ps", "--filter", f"name={DOCKER_CONTAINER}", "--format", "{{.Status}}"],
        capture_output=True,
        text=True,
        timeout=20,
    ).stdout.strip()
    with open(STATE, "w") as fh:
        fh.write(
            json.dumps(
                {
                    "at": time.time(),
                    "clients": len(wanted),
                    "changed": True,
                    "reload": how,
                    "container": ok,
                    "backup": backup,
                }
            )
        )
    print(f"клиентов в ядре: {len(have)} → {len(wanted)}; перезагрузка: {how}; контейнер: {ok}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
