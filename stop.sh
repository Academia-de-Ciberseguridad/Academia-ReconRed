#!/usr/bin/env bash
# Operación Red Recon — detener el laboratorio (conserva el progreso del scoreboard)
set -euo pipefail
cd "$(dirname "$0")"
echo "[*] Deteniendo el laboratorio..."
docker compose down
echo "[+] Laboratorio detenido. El progreso del scoreboard se conserva en el volumen."
echo "    Para borrar TODO (incluido el progreso):  docker compose down -v"
