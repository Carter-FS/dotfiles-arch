#!/bin/bash
# vpn.sh - status reporter (no args, used by waybar exec) and toggle (toggle arg, used by on-click).
# Brings up / tears down a ProtonVPN AU WireGuard tunnel via `wg-quick`.
# Requires: /etc/wireguard/proton-au.conf and a NOPASSWD sudoers rule for
# `wg-quick up proton-au` and `wg-quick down proton-au` (see /etc/sudoers.d/wg-quick-proton-au).

IFACE="proton-au"
SIGNAL_NUM=11   # must match "signal" in config.jsonc custom/vpn

is_connected() {
    ip link show "$IFACE" >/dev/null 2>&1
}

emit_status() {
    if is_connected; then
        printf '{"text": "󰒃 AU", "class": "connected", "tooltip": "ProtonVPN connected (AU) - click to disconnect"}\n'
    else
        printf '{"text": "󰌾 --", "class": "disconnected", "tooltip": "ProtonVPN disconnected - click to connect to AU"}\n'
    fi
}

toggle() {
    if is_connected; then
        sudo -n /usr/bin/wg-quick down "$IFACE" >/dev/null 2>&1
    else
        sudo -n /usr/bin/wg-quick up "$IFACE" >/dev/null 2>&1
    fi
    pkill -RTMIN+"$SIGNAL_NUM" waybar 2>/dev/null || true
}

case "${1:-status}" in
    toggle) toggle ;;
    status|*) emit_status ;;
esac
