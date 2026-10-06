#!/usr/bin/env python3
"""
Диагностика ядра на сервере узла (запускать НА УЗЛЕ, от root).

Отвечает на один вопрос: умеет ли ядро пускать клиентов с нашими ключами —
и чем именно отличается от ядра, которое держит панель Marzban.

Метод: поднимает ВТОРОЙ xray на тестовом порту с тем же privateKey/shortId и
тем же списком клиентов, затем гоняет через него реальный VLESS-трафик.
Ничего в проде не меняет, процессы убивает при выходе.
"""

import json
import os
import signal
import socket
import subprocess
import sys
import time

XRAY = os.environ.get("XRAY", "/opt/morok/xray/xray")
KEYS = "/var/lib/morok/reality-keys.json"
CLIENTS = "/var/lib/morok/xray-clients.json"
PROBE_PORT = int(os.environ.get("PROBE_PORT", 24443))
DB = "docker exec morok_postgres psql -U morok -d morok_vpn -tAc"


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def free(port, host="127.0.0.1"):
    with socket.socket() as s:
        return s.connect_ex((host, port)) == 0


def client_cfg(uuid, pub, sid, host, port, socks):
    return {
        "log": {"loglevel": "warning"},
        "inbounds": [{"port": socks, "protocol": "socks", "settings": {"auth": "noauth"}}],
        "outbounds": [
            {
                "protocol": "vless",
                "settings": {
                    "vnext": [
                        {
                            "address": host,
                            "port": port,
                            "users": [{"id": uuid, "encryption": "none", "flow": "xtls-rprx-vision"}],
                        }
                    ]
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "serverName": "telegram.org",
                        "fingerprint": "chrome",
                        "publicKey": pub,
                        "shortId": sid,
                        "spiderX": "/",
                    },
                },
            }
        ],
    }


def run_case(name, uuid, pub, sid, host, port, socks, server_proc=None):
    path = f"/tmp/morok-probe-client-{port}.json"
    json.dump(client_cfg(uuid, pub, sid, host, port, socks), open(path, "w"), indent=1)
    proc = subprocess.Popen([XRAY, "run", "-config", path], stdout=open(f"{path}.log", "w"), stderr=subprocess.STDOUT)
    end = time.time() + 15
    while time.time() < end and not free(socks):
        time.sleep(0.3)
    if not free(socks):
        print(f"{name}: клиентский xray не поднялся — {open(f'{path}.log').read()[-300:]}")
        proc.kill()
        return
    out = sh(f"curl -s -m 12 -x socks5h://127.0.0.1:{socks} -w '|%{{http_code}}' https://api.ipify.org")
    direct = sh("curl -s -m 8 https://api.ipify.org")
    err = ""
    try:
        log = open(f"{path}.log").read()
        for pat in ("processed invalid connection", "handshake failed", "done handshake", "auth failed"):
            if pat in log:
                err = pat
                break
    except OSError:
        pass
    ok = bool(out) and "|200" in out and out.split("|")[0] != direct
    print(f"{name}: {'ОТКРЫТ' if ok else 'ЗАКРЫТ'} (curl={out or 'пусто'}) {('— ' + err) if err else ''}")
    proc.send_signal(signal.SIGTERM)
    time.sleep(0.4)
    proc.kill()


def main():
    if not os.path.exists(XRAY):
        sys.exit(f"нет {XRAY} — выполни deploy/xray-sync/install-node.sh")
    keys = json.load(open(KEYS))
    clients = json.load(open(CLIENTS)).get("clients", [])
    if not clients:
        sys.exit("в /var/lib/morok/xray-clients.json пусто — нечем тестировать")
    uuid = clients[0]["id"]
    pub = sh(f"{DB} \"select \\\"publicKey\\\" from \\\"VpnServer\\\" where \\\"countryCode\\\"='PL'\"")
    sid = sh(f"{DB} \"select \\\"shortId\\\" from \\\"VpnServer\\\" where \\\"countryCode\\\"='PL'\"")
    print(f"ключ теста: uuid={uuid[:8]}… pbk={pub[:10]}… sid={sid}")
    print(f"pbk в БД == pbk из приватника ядра: ", end="")
    calc = sh(f"{XRAY} x25519 -i {keys['privateKey']} | awk '/Public key/{{print $3}}'")
    print("да" if calc == pub else f"НЕТ (ядро: {calc[:12]}…)")

    # 1) наше ядро на тестовом порту
    probe_cfg = {
        "log": {"loglevel": "warning"},
        "inbounds": [
            {
                "listen": "0.0.0.0",
                "port": PROBE_PORT,
                "protocol": "vless",
                "settings": {
                    "clients": [{"id": c["id"], "email": c.get("email", ""), "flow": "xtls-rprx-vision"} for c in clients],
                    "decryption": "none",
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "show": False,
                        "dest": keys.get("dest", "telegram.org:443"),
                        "xver": 0,
                        "serverNames": keys.get("serverNames", ["telegram.org"]),
                        "privateKey": keys["privateKey"],
                        "shortIds": keys.get("shortIds", [""]),
                        "maxTimediff": 0,
                    },
                },
            }
        ],
        "outbounds": [{"protocol": "freedom"}],
    }
    path = "/tmp/morok-probe-server.json"
    json.dump(probe_cfg, open(path, "w"), indent=1)
    srv = subprocess.Popen([XRAY, "run", "-config", path], stdout=open(path + ".log", "w"), stderr=subprocess.STDOUT)
    time.sleep(3)
    if srv.poll() is not None:
        print("наше ядро не стартовало:", open(path + ".log").read()[-400:])
        return
    try:
        run_case("наше ядро :%d" % PROBE_PORT, uuid, pub, sid, "127.0.0.1", PROBE_PORT, 16501, srv)
        # 2) ядро панели на :443 — ровно тот же клиент
        run_case("ядро панели :443", uuid, pub, sid, "127.0.0.1", 443, 16502, None)
    finally:
        srv.send_signal(signal.SIGTERM)
        time.sleep(0.5)
        srv.kill()


if __name__ == "__main__":
    main()
