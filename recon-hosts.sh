#!/usr/bin/env bash
# =============================================================================
# recon-hosts.sh — Registra (o elimina) los nombres de los objetivos del
# laboratorio en /etc/hosts, para poder escanear NATIVAMENTE desde tu Kali
# usando nombres (alpha, bravo, ...) en vez de IPs.
#
#   sudo ./recon-hosts.sh          # añade los nombres
#   sudo ./recon-hosts.sh --undo   # los elimina
#
# Tras ejecutarlo:  nmap alpha   |   curl http://bravo/   |   dig @foxtrot ...
# =============================================================================
set -euo pipefail
HOSTS=/etc/hosts
B="# >>> recon-lab >>>"
E="# <<< recon-lab <<<"

if [ "$(id -u)" -ne 0 ]; then
  echo "[!] Necesito privilegios para editar $HOSTS. Ejecuta:  sudo $0 ${1:-}"
  exit 1
fi

# Idempotente: elimina cualquier bloque previo del laboratorio.
if grep -qF "$B" "$HOSTS"; then
  sed -i "\|$B|,\|$E|d" "$HOSTS"
fi

if [ "${1:-}" = "--undo" ]; then
  echo "[+] Entradas de recon-lab eliminadas de $HOSTS."
  exit 0
fi

cat >> "$HOSTS" <<EOF
$B
172.30.0.5   scoreboard scoreboard.recon.lab
172.30.0.21  alpha   alpha.recon.lab
172.30.0.22  bravo   bravo.recon.lab
172.30.0.23  charlie charlie.recon.lab
172.30.0.24  delta   delta.recon.lab
172.30.0.25  echo    echo.recon.lab
172.30.0.26  foxtrot foxtrot.recon.lab
172.30.0.27  hotel   hotel.recon.lab
$E
EOF
echo "[+] Nombres de objetivos añadidos a $HOSTS."
echo "    Pruébalo:  nmap alpha   |   curl http://alpha/robots.txt   |   dig @foxtrot flag.recon.lab TXT"
echo "    Para revertir:  sudo $0 --undo"
