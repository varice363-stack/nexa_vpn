#!/usr/bin/env python3
"""
MOROK VPN — синхронизация клиентов с ядром Xray (TASK #030-C).

Вход:
  /var/lib/morok/reality-keys.json   privateKey/shortIds/dest/serverNames/port/apiPort
  /var/lib/morok/xray-clients.json   {"clients": [{id: <uuid ключа>, email: <id AccessKey>}]}
Выход:
  /etc/morok/xray/config.json        конфиг, с которым стартует morok-xray.service
  /var/lib/morok/xray-applied.json   что РЕАЛЬНО загружено в работающее ядро
  /var/lib/morok/xray-sync.state     диагностика для GET /provisioning/xray/status

Как применяется изменение (важно: SIGHUP здесь не работает):
  Xray 25.x на SIGHUP завершается, а systemd поднимает его заново через 2 с.
  Значит, `systemctl reload` = обрыв всех активных подключений. Поэтому:
    * только добавились клиенты  → горячо, через `xray api adu`, без перезапуска;
    * кто-то удалён / заблокирован / истёк → новые подключения закрываются через
      `xray api rmu`, а ядро перезапускается, чтобы оборвать уже идущие сессии
      (иначе заблокированный пользователь доигрывает текущую сессию);
    * изменились параметры ядра (Reality, API, policy) → перезапуск.
  Если горячее добавление не подтвердилось, падаем на перезапуск — сходимость важнее.

Состояние сверяется по xray-applied.json, а не по конфигу на диске: конфиг
может быть записан, а ядро при этом ещё не получило изменения.
"""

import fcntl
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time

KEYS = os.environ.get("XRAY_KEYS", "/var/lib/morok/reality-keys.json")
DESIRED = os.environ.get("XRAY_DESIRED", "/var/lib/morok/xray-clients.json")
CONFIG = os.environ.get("XRAY_CONFIG", "/etc/morok/xray/config.json")
APPLIED = os.environ.get("XRAY_APPLIED", "/var/lib/morok/xray-applied.json")
STATE = os.environ.get("XRAY_STATE", "/var/lib/morok/xray-sync.state")
LOCK = os.environ.get("XRAY_LOCK", "/run/morok-xray-sync.lock")
UNIT = os.environ.get("XRAY_UNIT", "morok-xray")
# Для тестов можно подменить команду перезапуска; на проде — systemctl.
RESTART_CMD = os.environ.get("XRAY_RESTART_CMD")
XRAY_BIN = os.environ.get("XRAY_BIN", "/opt/morok/xray/xray")
TAG = "VLESS-Reality"
QUIET = "--quiet" in sys.argv


def log(*a):
    if not QUIET:
        print("[morok-xray]", *a, flush=True)


def read_json(path, default=None):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        if default is None:
            raise SystemExit(f"нет файла {path} — сначала выполни install.sh")
        return default


def load_optional(path):
    """Файл может отсутствовать (первый запуск) — тогда None, без ошибки."""
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None


def atomic_write(path, text):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".tmp-")
    with os.fdopen(fd, "w") as fh:
        fh.write(text)
    # mkstemp даёт 0600; systemd-юнит работает с UMask=0077. Файлы не секретные
    # (UUID ключей и счётчики), а backend читает состояние — делаем 0644 явно.
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def desired_clients():
    doc = read_json(DESIRED, {"clients": []})
    seen, out = set(), []
    for c in doc.get("clients") or []:
        cid = (c or {}).get("id")
        if cid and cid not in seen:
            seen.add(cid)
            out.append({"id": cid, "email": str(c.get("email") or cid)[:64], "flow": "xtls-rprx-vision"})
    # порядок фиксируем: иначе отпечаток меняется на ровном месте
    return sorted(out, key=lambda x: x["id"])


def build(clients):
    k = read_json(KEYS)
    port = int(k.get("port") or 443)
    api_port = int(k.get("apiPort") or 10085)
    return {
        "log": {"loglevel": "warning"},  # access-лог не ведём
        # StatsService — трафик по ключам; HandlerService — горячее добавление/удаление.
        # Слушает только петлю.
        "api": {"tag": "api", "listen": f"127.0.0.1:{api_port}", "services": ["StatsService", "HandlerService"]},
        "stats": {},
        "inbounds": [
            {
                "listen": "0.0.0.0",
                "port": port,
                "protocol": "vless",
                "tag": TAG,
                "settings": {"clients": clients, "decryption": "none", "fallbacks": []},
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "show": False,
                        "dest": k.get("dest") or "telegram.org:443",
                        "xver": 0,
                        "serverNames": k.get("serverNames") or ["telegram.org"],
                        "privateKey": k["privateKey"],
                        "shortIds": k.get("shortIds") or [""],
                        "maxTimediff": 0,
                    },
                },
                "sniffing": {"enabled": True, "destOverride": ["http", "tls", "quic"]},
            }
        ],
        "outbounds": [{"protocol": "freedom", "tag": "DIRECT"}, {"protocol": "blackhole", "tag": "BLOCK"}],
        "policy": {
            "levels": {
                "0": {
                    "handshake": 4,
                    "connIdle": 300,
                    "idleTimeout": 60,
                    # Без этих флагов Xray не считает трафик по клиентам.
                    "statsUserUplink": True,
                    "statsUserDownlink": True,
                }
            }
        },
    }


def static_sig(cfg):
    """Отпечаток всего, КРОМЕ списка клиентов. Изменился — нужен перезапуск."""
    inbound = {k: v for k, v in cfg["inbounds"][0].items() if k != "settings"}
    inbound["settings"] = {k: v for k, v in cfg["inbounds"][0]["settings"].items() if k != "clients"}
    core = json.dumps(
        {"inbound": inbound, "api": cfg.get("api"), "stats": cfg.get("stats"), "policy": cfg.get("policy"),
         "outbounds": cfg.get("outbounds")},
        sort_keys=True,
    ).encode()
    return hashlib.sha256(core).hexdigest()


def read_applied():
    """Что загружено в ядро. Если файла нет (первый запуск после обновления) — берём из конфига."""
    doc = load_optional(APPLIED)
    if doc is not None:
        return doc
    if os.path.exists(CONFIG):
        try:
            old = read_json(CONFIG)
            ids = [c["id"] for c in old["inbounds"][0]["settings"].get("clients", [])]
            return {"sig": static_sig(old), "clients": ids}
        except (SystemExit, KeyError, IndexError, ValueError, TypeError):
            return None
    return None


def write_applied(sig, ids):
    atomic_write(APPLIED, json.dumps({"sig": sig, "clients": ids, "at": time.time()}))


def write_config(cfg):
    if os.path.exists(CONFIG):
        with open(CONFIG) as fh:
            prev = fh.read()
        atomic_write(CONFIG + ".bak", prev)
    atomic_write(CONFIG, json.dumps(cfg, indent=2, ensure_ascii=False))


def unit_active():
    r = subprocess.run(["systemctl", "is-active", UNIT], capture_output=True, text=True)
    return r.stdout.strip() == "active"


def restart_core():
    """True — перезапуск выполнен; False — ошибка; None — пропущено (ядро не наше)."""
    if RESTART_CMD:
        cmd = shlex.split(RESTART_CMD)
    else:
        if not unit_active():
            return None  # юнита нет — ядро пока принадлежит панели: не трогаем
        cmd = ["systemctl", "restart", UNIT]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return r.returncode == 0


def hot_add(clients, port):
    """Добавить клиентов в работающее ядро. Успех — только если ядро подтвердило число."""
    payload = {
        "inbounds": [
            {
                "listen": "127.0.0.1",
                "port": port,
                "tag": TAG,
                "protocol": "vless",
                "settings": {"clients": clients, "decryption": "none"},
            }
        ]
    }
    fd, path = tempfile.mkstemp(prefix="adu-", suffix=".json")
    with os.fdopen(fd, "w") as fh:
        json.dump(payload, fh)
    try:
        api = f"127.0.0.1:{int(read_json(KEYS).get('apiPort') or 10085)}"
        r = subprocess.run([XRAY_BIN, "api", "adu", f"--server={api}", path],
                           capture_output=True, text=True, timeout=60)
    finally:
        os.unlink(path)
    out = (r.stdout or "") + (r.stderr or "")
    # rc у `xray api adu` = 0 даже при ошибке — смотрим на текст.
    ok = f"Added {len(clients)} user(s)" in out and "failed" not in out.lower()
    if not ok:
        log("горячее добавление не подтвердилось:", out.strip()[-300:])
    return ok


def core_clients_count(applied):
    return len(applied["clients"]) if applied else None


def write_state(clients_count, action):
    try:
        atomic_write(
            STATE,
            json.dumps(
                {"at": time.time(), "clients": clients_count, "coreClients": clients_count,
                 "changed": action != "noop", "action": action, "source": "build-xray-config"}
            ),
        )
    except OSError:
        pass  # статус — диагностика, а не условие работы ядра


def main():
    os.makedirs(os.path.dirname(LOCK) or ".", exist_ok=True)
    lock_fh = open(LOCK, "w")
    fcntl.flock(lock_fh, fcntl.LOCK_EX)  # два запуска (path + cron) не должны мешать друг другу

    clients = desired_clients()
    cfg = build(clients)
    want_sig = static_sig(cfg)
    want_ids = [c["id"] for c in clients]
    applied = read_applied()
    port = int(read_json(KEYS).get("port") or 443)

    if applied is None or applied["sig"] != want_sig:
        action = "restart-config"
        write_config(cfg)
        res = restart_core()
    else:
        applied_ids = set(applied["clients"])
        added = [c for c in clients if c["id"] not in applied_ids]
        removed = [i for i in applied["clients"] if i not in set(want_ids)]
        if not added and not removed:
            action = "noop"
            res = True
        elif removed:
            action = "restart-removed"
            write_config(cfg)
            res = restart_core()
        else:
            action = "hot-add"
            write_config(cfg)  # файл должен совпадать с желаемым — на случай будущего перезапуска
            res = hot_add(added, port)
            if not res:
                action = "restart-after-failed-hot-add"
                res = restart_core()

    if res is None:
        log("ядро не управляется этим скриптом (юнит не активен) — пропуск")
        write_state(len(want_ids), "skipped")
        return 0
    if res is False:
        log(f"применение не удалось: {action}")
        write_state(len(want_ids), action + "-FAILED")
        return 1

    if action != "noop":
        write_applied(want_sig, want_ids)
    write_state(len(want_ids), action)
    log(f"клиентов: {len(want_ids)}; действие: {action}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
