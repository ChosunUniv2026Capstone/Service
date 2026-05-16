#!/bin/sh
set -eu

: "${COLLECTOR_AP_ID:?COLLECTOR_AP_ID is required}"
: "${PRESENCE_COLLECTOR_URL:?PRESENCE_COLLECTOR_URL is required, e.g. https://smart-class.org/presence/collector}"
: "${PRESENCE_COLLECTOR_TOKEN:?PRESENCE_COLLECTOR_TOKEN is required}"
COLLECTOR_INTERFACES="${COLLECTOR_INTERFACES:-}"
PUSH_INTERVAL_SECONDS="${PUSH_INTERVAL_SECONDS:-3}"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

interfaces() {
  if [ -n "$COLLECTOR_INTERFACES" ]; then
    printf '%s\n' $COLLECTOR_INTERFACES
    return
  fi
  iw dev 2>/dev/null | awk '/Interface /{print $2}'
}

station_json() {
  iface="$1"
  iw dev "$iface" station dump 2>/dev/null | awk '
    function flush() {
      if (mac != "") {
        if (count++ > 0) printf ","
        printf "{\"mac\":\"%s\",\"associated\":true,\"authenticated\":true,\"authorized\":true,\"signalDbm\":%d,\"connectedSeconds\":%d,\"rxBytes\":%d,\"txBytes\":%d}", mac, signal, connected, rx, tx
      }
    }
    /^Station / { flush(); mac=$2; signal=-50; connected=0; rx=0; tx=0 }
    /signal:/ { signal=$2 }
    /connected time:/ { connected=$3 }
    /rx bytes:/ { rx=$3 }
    /tx bytes:/ { tx=$3 }
    END { flush() }
  '
}

build_payload() {
  observed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '{"collectorApId":"%s","observedAt":"%s","interfaces":[' "$(json_escape "$COLLECTOR_AP_ID")" "$observed"
  first_iface=1
  for iface in $(interfaces); do
    [ -n "$iface" ] || continue
    ssid="$(iw dev "$iface" info 2>/dev/null | awk '/ssid /{print substr($0, index($0,$2)); exit}' || true)"
    bssid="$(iw dev "$iface" info 2>/dev/null | awk '/addr /{print $2; exit}' || true)"
    if [ "$first_iface" -eq 0 ]; then printf ','; fi
    first_iface=0
    printf '{"interfaceId":"%s","ssid":"%s","bssid":"%s","stations":[' "$(json_escape "$iface")" "$(json_escape "$ssid")" "$(json_escape "$bssid")"
    station_json "$iface"
    printf ']}'
  done
  printf ']}'
}

while true; do
  payload="$(build_payload)"
  nonce="$(date +%s)-$$-$RANDOM"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  curl -fsS \
    -H "Authorization: Bearer ${PRESENCE_COLLECTOR_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "X-Collector-Nonce: ${nonce}" \
    -H "X-Collector-Timestamp: ${timestamp}" \
    -X POST \
    --data "$payload" \
    "${PRESENCE_COLLECTOR_URL%/}/aps/${COLLECTOR_AP_ID}/snapshot" >/dev/null || true
  sleep "$PUSH_INTERVAL_SECONDS"
done
