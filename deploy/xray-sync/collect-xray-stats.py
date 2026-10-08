#!/usr/bin/env python3
"""
MOROK VPN — сбор реального трафика ключей из ядра Xray.

Зачем: панель показывает «израсходовано / лимит». Без этих цифр лимит трафика
был бы надписью, которая ничего не ограничивает, а владелец не знал бы, кто
сколько съел.

Как: раз в минуту (systemd-таймер morok-xray-stats.timer) спрашиваем у ядра
через локальный API:
    xray api statsquery --server=127.0.0.1:10085 -pattern "user>>>" -reset=false
и складываем результат в /var/lib/morok/xray-stats.json:
    { "<первые 8 символов id ключа>": {"up": байты, "down": байты} }
Ровно этот файл читает бэкенд (XrayStatsService).

Тонкость, из-за которой нужен второй файл: Xray держит счётчики В ПАМЯТИ и
обнуляет их при каждом reload конфига (а reload у нас случается при любой
правке списка клиентов). Если писать сырые значения как есть, счётчик
«израсходовано» каждые несколько минут начинал бы с нуля. Поэтому ведём
накопитель: raw-файл хранит последнее сырое значение, и в общий файл пишется
сумма приращений. Уменьшение сырого значения = ядро перезапустилось, тогда
приращением считается всё текущее значение.
"""

import json
import os
import subprocess
import sys
import time

XRAY_BIN = os.environ.get("XRAY_BIN", "/opt/morok/xray/xray")
API_SERVER = os.environ.get("XRAY_API", "127.0.0.1:10085")
OUT = os.environ.get("XRAY_STATS", "/var/lib/morok/xray-stats.json")
RAW = os.environ.get("XRAY_STATS_RAW", "/var/lib/morok/xray-stats.raw.json")
PATTERN = os.environ.get("XRAY_STATS_PATTERN", "user>>>")
QUIET = "--quiet" in sys.argv


def log(*a):
    if not QUIET:
        print("[morok-xray-stats]", *a)


def read_json(path, default):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return default


def write_json(path, doc):
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(doc, fh)
    os.replace(tmp, path)


def query_core():
    """Сырые счётчики: {email: {"up": байты, "down": байты}}."""
    proc = subprocess.run(
        [XRAY_BIN, "api", "statsquery", f"--server={API_SERVER}", "-pattern", PATTERN, "-reset=false"],
        capture_output=True,
        text=True,
        timeout=25,
    )
    if proc.returncode != 0:
        raise RuntimeError((proc.stderr or proc.stdout or "statsquery failed").strip()[:300])

    try:
        doc = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"statsquery вернул не JSON: {exc}") from exc

    out = {}
    for stat in doc.get("stat") or []:
        name = str(stat.get("name") or "")
        parts = name.split(">>>")
        # Формат: user>>>{email}>>>traffic>>>{uplink|downlink}
        if len(parts) != 4 or parts[0] != "user" or parts[2] != "traffic":
            continue
        kind = "up" if parts[3] == "uplink" else ("down" if parts[3] == "downlink" else None)
        if kind is None:
            continue
        try:
            value = int(stat.get("value") or 0)
        except (TypeError, ValueError):
            continue
        out.setdefault(parts[1], {"up": 0, "down": 0})[kind] = value
    return out


def accumulate(current, prev_raw, prev_total):
    total = {}
    for email, cur in current.items():
        base = prev_total.get(email) or {"up": 0, "down": 0}
        last = prev_raw.get(email) or {"up": 0, "down": 0}
        row = {}
        for kind in ("up", "down"):
            prev_value = int(last.get(kind, 0) or 0)
            value = int(cur.get(kind, 0) or 0)
            # value < prev_value → счётчик сбросился (reload ядра): считаем, что
            # израсходовано всё текущее значение.
            delta = value - prev_value if value >= prev_value else value
            row[kind] = int(base.get(kind, 0) or 0) + max(0, delta)
        total[email] = row

    # Ключи, которых нет в текущем ответе (клиент убран из ядра), сохраняют
    # накопленное: иначе «израсходовано» обнулялось бы при каждом отзыве.
    for email, row in prev_total.items():
        total.setdefault(email, row)
    return total


def main():
    try:
        current = query_core()
    except Exception as exc:  # noqa: BLE001 — сборщик не имеет права падать громко
        log(f"нет данных от ядра: {exc}")
        return 0

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    prev_raw = read_json(RAW, {})
    prev_total = read_json(OUT, {})
    total = accumulate(current, prev_raw, prev_total)

    write_json(RAW, current)
    write_json(OUT, total)
    grand = sum(int(v.get("up", 0)) + int(v.get("down", 0)) for v in total.values())
    log(
        "ключей: %d, суммарно %.1f МБ, обновлено %s"
        % (len(total), grand / 1048576, time.strftime("%H:%M:%S"))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
