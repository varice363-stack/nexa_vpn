"""
Тесты сборщика build-xray-config.py (запуск: python3 -m unittest -v deploy/xray-sync/test_build_xray_config.py).

Настоящий Xray не нужен: `xray api adu` подменяется сценарием, перезапуск —
скриптом, который пишет строку в журнал. Проверяется ВЫБОР действия:
добавление — горячо; удаление/смена параметров — перезапуск; сбой горячего
добавления — откат на перезапуск; повтор без изменений — ничего не делаем.
"""
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "build-xray-config.py")

FAKE_XRAY = """#!/usr/bin/env python3
import json, sys
args = sys.argv[1:]
if args[:2] == ["api", "adu"]:
    if open(os.environ["FAKE_ADU_MODE"]).read().strip() == "fail":
        print("failed to build config: boom")
        sys.exit(0)  # настоящий xray api adu отдаёт rc=0 даже при ошибке
    doc = json.load(open(args[-1]))
    n = sum(len(i["settings"]["clients"]) for i in doc["inbounds"])
    print("processing inbound: VLESS-Reality")
    print(f"Added {n} user(s) in total.")
    sys.exit(0)
sys.exit(1)
""".replace("import json, sys", "import json, os, sys")

RESTART_SH = """#!/bin/sh
echo restart >> "$(dirname "$0")/restarts.log"
"""


class XraySyncTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="xsync-")
        d = self.dir
        self.env = {
            "XRAY_KEYS": f"{d}/keys.json",
            "XRAY_DESIRED": f"{d}/desired.json",
            "XRAY_CONFIG": f"{d}/config.json",
            "XRAY_APPLIED": f"{d}/applied.json",
            "XRAY_STATE": f"{d}/state.json",
            "XRAY_LOCK": f"{d}/lock",
            "XRAY_RESTART_CMD": f"{d}/restart.sh",
            "XRAY_BIN": f"{d}/xray",
            "FAKE_ADU_MODE": f"{d}/adu_mode",
        }
        self._write(f"{d}/restart.sh", RESTART_SH, executable=True)
        self._write(f"{d}/xray", FAKE_XRAY, executable=True)
        self._write(f"{d}/adu_mode", "ok")
        self._write_json(f"{d}/keys.json", {
            "privateKey": "CIUT5msSn_O3diLNQwblrqxLnocMWKxN0qStaf970D8",
            "port": 443, "apiPort": 10085, "dest": "telegram.org:443",
            "serverNames": ["telegram.org"], "shortIds": ["6f8d1a2b3c4d5e6f"],
        })
        self.ids = {n: str(uuid.uuid4()) for n in "ABCD"}

    def _write(self, path, text, executable=False):
        with open(path, "w") as fh:
            fh.write(text)
        if executable:
            os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC)

    def _write_json(self, path, obj):
        with open(path, "w") as fh:
            json.dump(obj, fh)

    def desired(self, *names):
        self._write_json(self.env["XRAY_DESIRED"], {
            "clients": [{"id": self.ids[n], "email": self.ids[n][:8]} for n in names]})

    def run_sync(self):
        env = dict(os.environ, **self.env)
        r = subprocess.run([sys.executable, SCRIPT, "--quiet"], env=env,
                           capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        with open(self.env["XRAY_STATE"]) as fh:
            return json.load(fh)["action"]

    def restarts(self):
        p = os.path.join(self.dir, "restarts.log")
        if not os.path.exists(p):
            return 0
        with open(p) as fh:
            return len(fh.read().splitlines())

    def test_first_run_writes_config_and_restarts_once(self):
        self.desired("A")
        self.assertEqual(self.run_sync(), "restart-config")
        self.assertEqual(self.restarts(), 1)
        with open(self.env["XRAY_CONFIG"]) as fh:
            cfg = json.load(fh)
        self.assertIn("HandlerService", cfg["api"]["services"])
        self.assertEqual([c["id"] for c in cfg["inbounds"][0]["settings"]["clients"]], [self.ids["A"]])

    def test_adding_a_client_is_hot_and_does_not_restart(self):
        self.desired("A")
        self.run_sync()
        before = self.restarts()
        self.desired("A", "B")
        self.assertEqual(self.run_sync(), "hot-add")
        self.assertEqual(self.restarts(), before, "добавление не должно перезапускать ядро")

    def test_failed_hot_add_falls_back_to_restart(self):
        self.desired("A")
        self.run_sync()
        self._write(self.env["FAKE_ADU_MODE"], "fail")
        before = self.restarts()
        self.desired("A", "B")
        self.assertEqual(self.run_sync(), "restart-after-failed-hot-add")
        self.assertEqual(self.restarts(), before + 1)

    def test_removing_a_client_restarts_to_cut_live_sessions(self):
        self.desired("A", "B")
        self.run_sync()
        before = self.restarts()
        self.desired("B")
        self.assertEqual(self.run_sync(), "restart-removed")
        self.assertEqual(self.restarts(), before + 1)

    def test_no_change_is_noop(self):
        self.desired("A")
        self.run_sync()
        before = self.restarts()
        self.assertEqual(self.run_sync(), "noop")
        self.assertEqual(self.restarts(), before)

    def test_core_parameter_change_restarts(self):
        self.desired("A")
        self.run_sync()
        with open(self.env["XRAY_KEYS"]) as fh:
            keys = json.load(fh)
        keys["shortIds"] = ["aaaaaaaaaaaaaaaa"]
        self._write_json(self.env["XRAY_KEYS"], keys)
        before = self.restarts()
        self.assertEqual(self.run_sync(), "restart-config")
        self.assertEqual(self.restarts(), before + 1)

    def test_duplicate_ids_are_applied_once(self):
        self._write_json(self.env["XRAY_DESIRED"], {"clients": [
            {"id": self.ids["A"], "email": "x"}, {"id": self.ids["A"], "email": "y"}]})
        self.assertEqual(self.run_sync(), "restart-config")
        with open(self.env["XRAY_CONFIG"]) as fh:
            self.assertEqual(len(json.load(fh)["inbounds"][0]["settings"]["clients"]), 1)


if __name__ == "__main__":
    unittest.main()
