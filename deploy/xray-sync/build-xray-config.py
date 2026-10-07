#!/usr/bin/env python3
"""
MOROK VPN — сборка конфига ядра из того, что выдал бэкенд (TASK #030-B).

Вход:
  /var/lib/morok/reality-keys.json   privateKey/shortIds/dest/serverNames/port
  /var/lib/morok/xray-clients.json   [{id: <uuid ключа>, email: <id AccessKey>}]
Выход:
  /etc/morok/xray/config.json        конфиг, который читает morok-xray.service

Почему не правка конфига Marzban: панель держит ядро как `xray run -config stdin:`
и генерирует конфиг сама — файловая правка до неё не доходит (проверено живьём:
3 клиента в файле, handshake по-прежнему «processed invalid connection»).

Ключевое: конфиг перезаписывается ТОЛЬКО когда содержимое реально изменилось
(сравнение по хэшу «ключевой» части). Лишний SIGHUP = разрыв всех активных
туннелей, поэтому просто так мы ядро не трогаем.
"""

import hashlib
import json
import os
import subprocess
import sys
import time

KEYS = "/var/lib/morok/reality-keys.json"
DESIRED = "/var/lib/morok/xray-clients.json"
CONFIG = os.environ.get("XRAY_CONFIG", "/etc/morok/xray/config.json")
# Стейт читается бэкендом (GET /provisioning/xray/status): по нему панель
# понимает, когда узел в последний раз применял список.
STATE = os.environ.get("XRAY_STATE", "/var/lib/morok/xray-sync.state")
UNIT = os.environ.get("XRAY_UNIT", "morok-xray")

QUIET = "--quiet" in sys.argv


def log(*a):
    if not QUIET:
        print("[morok-xray]", *a)


def read_json(path, default=None):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        if default is None:
            raise SystemExit(f"нет файла {path} — сначала выполни install-node.sh")
        return default


def clients():
    doc = read_json(DESIRED, {"clients": []})
    out = []
    for c in doc.get("clients") or []:
        cid = (c or {}).get("id")
        if cid:
            out.append({"id": cid, "email": str(c.get("email") or cid)[:64], "flow": "xtls-rprx-vision"})
    # порядок фиксируем: иначе hash меняется на ровном месте и гоняет SIGHUP
    return sorted(out, key=lambda x: x["id"])


def build():
    k = read_json(KEYS)
    inbound = {
        "listen": "0.0.0.0",
        "port": int(k.get("port") or 443),
        "protocol": "vless",
        "tag": "VLESS-Reality",
        "settings": {"clients": clients(), "decryption": "none", "fallbacks": []},
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
    return {
        "log": {"loglevel": "warning"},  # access-лог не ведём: см. docs/RISK_ASSESSMENT_RF.md
        "inbounds": [inbound],
        "outbounds": [{"protocol": "freedom", "tag": "DIRECT"}, {"protocol": "blackhole", "tag": "BLOCK"}],
        "policy": {"levels": {"0": {"handshake": 4, "connIdle": 300, "idleTimeout": 60}}},
    }


def sig_of(cfg):
    core = json.dumps(cfg["inbounds"][0], sort_keys=True).encode()
    return hashlib.sha256(core).hexdigest()


def reload_core():
    """Перезапуск ядра без обрыва соединений, если умеем; иначе — nothing."""
    r = subprocess.run(["systemctl", "is-active", UNIT], capture_output=True, text=True)
    if r.stdout.strip() == "active":
        subprocess.run(["systemctl", "reload", UNIT], capture_output=True, text=True)
        return "systemctl-reload"
    # Юнита нет — значит ядро пока принадлежит панели: трогаем только своё.
    return "skip (unit %s не активен)" % UNIT


def write_state(clients_count, changed):
    """Стейт для GET /provisioning/xray/status.

    Пишется в ОБЕИХ ветках — и при «без изменений», и после применения.
    Раньше запись стояла только в ветке «без изменений», поэтому
    nodeAppliedAt уезжал в момент первой установки и панель вечно показывала
    «узел отстал на N часов», хотя ядро перезапускалось каждую минуту.
    """
    try:
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        tmp = STATE + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(
                {
                    "at": time.time(),
                    "clients": clients_count,
                    "changed": changed,
                    "source": "build-xray-config",
                },
                fh,
            )
        os.replace(tmp, STATE)
    except OSError:
        pass  # статус — диагностика, а не условие работы ядра


def main():
    cfg = build()
    want = sig_of(cfg)
    old = None
    if os.path.exists(CONFIG):
        try:
            old = sig_of(read_json(CONFIG))
        except SystemExit:
            old = None
    if old == want:
        n = len(cfg["inbounds"][0]["settings"]["clients"])
        write_state(n, False)
        log(f"без изменений: {n} клиентов в ядре")
        return 0

    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    if os.path.exists(CONFIG):
        with open(CONFIG) as fh:
            prev = fh.read()
        tmp = CONFIG + ".bak"
        with open(tmp, "w") as fh:
            fh.write(prev)
    tmp = CONFIG + ".new"
    with open(tmp, "w") as fh:
        json.dump(cfg, fh, indent=2, ensure_ascii=False)
    os.replace(tmp, CONFIG)
    n = len(cfg["inbounds"][0]["settings"]["clients"])
    how = reload_core()
    write_state(n, True)
    log(f"конфиг переписан, клиентов: {n}; применение: {how}")
    return 0


if __name__ == "__main__":
    main()
