#!/usr/bin/env bash
set -euo pipefail

# Collect infra facts from gw/master/worker nodes into ./out/<host>/
# Usage:
#   ./collect-infra.sh -h "gw master worker01 worker02 worker03" \
#     -u root --ask-pass
#   ./collect-infra.sh -h "192.168.1.100 192.168.1.240 192.168.1.151" \
#     -u root -p 'password'

usage() {
  cat <<'USAGE'
collect-infra.sh

Options:
  -h "host1 host2 ..."   Space-separated hostnames/IPs
  -u USER                SSH user (default: root)
  -p PASS                SSH password (optional)
  --ask-pass             Prompt for SSH password
  --identity PATH        SSH identity file (optional)
  --port PORT            SSH port (default: 22)
  --out DIR              Output dir (default: ./out)
  --help                 Show help

Examples:
  ./collect-infra.sh -h "gw master worker01" -u root --ask-pass
  ./collect-infra.sh -h "192.168.1.100 192.168.1.240" -u root -p '***'
USAGE
}

HOSTS=""
USER="root"
PASS=""
ASK_PASS=0
IDENTITY=""
PORT=22
OUT_DIR="./out"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h) HOSTS="$2"; shift 2;;
    -u) USER="$2"; shift 2;;
    -p) PASS="$2"; shift 2;;
    --ask-pass) ASK_PASS=1; shift 1;;
    --identity) IDENTITY="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --out) OUT_DIR="$2"; shift 2;;
    --help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
 done

if [[ -z "$HOSTS" ]]; then
  echo "Missing -h hosts"
  usage
  exit 1
fi

if [[ $ASK_PASS -eq 1 && -z "$PASS" ]]; then
  read -s -p "SSH password: " PASS
  echo
fi

SSH_BASE=(ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts -p "$PORT")
if [[ -n "$IDENTITY" ]]; then
  SSH_BASE+=( -i "$IDENTITY" )
fi

run_ssh() {
  local host="$1"; shift
  if [[ -n "$PASS" ]]; then
    sshpass -p "$PASS" "${SSH_BASE[@]}" "$USER@$host" "$@"
  else
    "${SSH_BASE[@]}" "$USER@$host" "$@"
  fi
}

mkdir -p "$OUT_DIR"

for host in $HOSTS; do
  safe_host=$(echo "$host" | tr '/:' '__')
  dest="$OUT_DIR/$safe_host"
  mkdir -p "$dest"
  echo "==> Collecting from $host -> $dest"

  run_ssh "$host" "hostname; hostname -I" > "$dest/identity.txt" || true
  run_ssh "$host" "uname -a" > "$dest/uname.txt" || true
  run_ssh "$host" "cat /etc/os-release" > "$dest/os-release.txt" || true
  run_ssh "$host" "ip -br link" > "$dest/ip-link.txt" || true
  run_ssh "$host" "ip -br addr" > "$dest/ip-addr.txt" || true
  run_ssh "$host" "ip route" > "$dest/ip-route.txt" || true
  run_ssh "$host" "resolvectl status" > "$dest/resolvectl.txt" || true
  run_ssh "$host" "cat /etc/resolv.conf" > "$dest/resolv.conf.txt" || true

  run_ssh "$host" "systemctl --no-pager --full status k3s k3s-agent || true" > "$dest/k3s-status.txt" || true
  run_ssh "$host" "systemctl --no-pager --full status sing-box dnsmasq dnscrypt-proxy netfilter-persistent autossh-admin || true" > "$dest/services-status.txt" || true

  run_ssh "$host" "ls -l /etc/rancher/k3s /etc/rancher/k3s/config.yaml /etc/rancher/k3s/registries.yaml 2>/dev/null" > "$dest/k3s-files.txt" || true
  run_ssh "$host" "cat /etc/rancher/k3s/config.yaml 2>/dev/null" > "$dest/k3s-config.yaml" || true
  run_ssh "$host" "cat /etc/rancher/k3s/registries.yaml 2>/dev/null" > "$dest/k3s-registries.yaml" || true

  run_ssh "$host" "cat /etc/sing-box/config.json 2>/dev/null" > "$dest/sing-box.json" || true
  run_ssh "$host" "cat /etc/dnsmasq.d/forward-doh.conf 2>/dev/null" > "$dest/dnsmasq-forward.conf" || true
  run_ssh "$host" "cat /etc/dnscrypt-proxy/dnscrypt-proxy.toml 2>/dev/null" > "$dest/dnscrypt-proxy.toml" || true

  run_ssh "$host" "iptables-save" > "$dest/iptables-save.txt" || true
  run_ssh "$host" "ipset list" > "$dest/ipset-list.txt" || true
  run_ssh "$host" "sysctl -a 2>/dev/null | grep -E 'ipv4.conf|ipv6.conf'" > "$dest/sysctl-net.txt" || true

done

echo "Done. Output in $OUT_DIR/"
