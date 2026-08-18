#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Nexa VPN — Xray node bootstrap (Debian/Ubuntu VPS)
# TASK #013 deployment kit. Run as root on a FRESH VPS.
#
#   bash xray-node-setup.sh
#
# After setup: fill the VpnServer row in the Nexa backend with the
# generated PUBLIC parameters (see docs/XRAY_NODE.md). The privateKey
# NEVER leaves this server.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "==> Installing Xray-core (official script)"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo "==> Generating REALITY keypair"
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep Private | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEYS"  | grep Public  | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 8)
UUID=$(cat /proc/sys/kernel/random/uuid)

echo "==> Writing server config (privateKey stays on this machine only)"
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "${UUID}", "flow": "xtls-rprx-vision" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": ["www.microsoft.com"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" } ]
}
EOF

echo "==> Restarting Xray"
systemctl restart xray
systemctl enable xray

echo
echo "════════════════════════════════════════════════════════════════"
echo " XRAY NODE READY — public parameters for Nexa backend:"
echo "   host:      $(curl -s https://api.ipify.org)"
echo "   port:      443"
echo "   transport: tcp"
echo "   security:  reality"
echo "   sni:       www.microsoft.com"
echo "   flow:      xtls-rprx-vision"
echo "   publicKey: ${PUBLIC_KEY}"
echo "   shortId:   ${SHORT_ID}"
echo "   (test client uuid: ${UUID})"
echo "════════════════════════════════════════════════════════════════"
echo
echo "Firewall: open TCP 443 (ufw allow 443/tcp)."
echo "The PRIVATE KEY was written to /usr/local/etc/xray/config.json ONLY."
echo "Never copy it to the Nexa backend — public params are enough."
