from __future__ import annotations

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
COLLECTOR = ROOT / "openwrt" / "presence-collector.sh"


def _station_awk_program() -> str:
    script = COLLECTOR.read_text()
    marker = 'iw dev "$iface" station dump 2>/dev/null | awk \'\n'
    start = script.index(marker) + len(marker)
    end = script.index("\n  '\n}", start)
    return script[start:end]


def test_station_parser_uses_primary_signal_line_not_ack_signal() -> None:
    fixture = """Station 32:76:82:a2:f8:48 (on phy1-ap0)
\tinactive time:\t10 ms
\trx bytes:\t862474
\ttx bytes:\t569173
\tsignal:\t-50 [-54, -50] dBm
\tconnected time:\t565 seconds
\tavg ack signal:\t-49 dBm
"""

    result = subprocess.run(
        ["awk", _station_awk_program()],
        input=fixture,
        text=True,
        check=True,
        stdout=subprocess.PIPE,
    )

    station = json.loads(result.stdout)
    assert station["mac"] == "32:76:82:a2:f8:48"
    assert station["signalDbm"] == -50
    assert station["connectedSeconds"] == 565
    assert station["rxBytes"] == 862474
    assert station["txBytes"] == 569173
