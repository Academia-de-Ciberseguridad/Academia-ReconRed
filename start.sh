#!/usr/bin/env bash
# Operación Red Recon — arranque rápido del laboratorio
set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YEL='\033[1;33m'; NC='\033[0m'

banner() {
cat <<'EOF'
   ____                       _   _               ____
  / __ \ ___  ___ _______    | \ | | ___  __ __  / __ \___ _______  ___
 / /_/ // _ \/ -_) __/ _ `/  |  \| |/ -_)/ // / / /_/ / -_) __/ _ \/ _ \
 \____// .__/\__/\__/\_,_/   |_|\__|\__/ \_,_/ /_/ |_|\__/\__/\___/_//_/
     /_/        O P E R A C I O N   R E D   R E C O N   ·   LAB v1.0
EOF
}

banner
echo -e "${CYAN}[*] Comprobando Docker...${NC}"
if ! docker info >/dev/null 2>&1; then
  echo -e "${YEL}[!] Docker no está disponible o no tienes permisos. ¿Está arrancado?${NC}"
  exit 1
fi

echo -e "${CYAN}[*] Validando docker-compose.yml...${NC}"
docker compose config -q

echo -e "${CYAN}[*] Construyendo imágenes (puede tardar la primera vez)...${NC}"
docker compose build

echo -e "${CYAN}[*] Levantando el laboratorio...${NC}"
docker compose up -d

echo ""
echo -e "${GREEN}[+] Laboratorio ARRIBA.${NC}"
echo -e "${GREEN}[+] Scoreboard:${NC}   http://localhost:8080"
echo -e "${GREEN}[+] Objetivos:${NC}    172.30.0.21–172.30.0.27 (escanéalos NATIVAMENTE desde tu Kali)"
echo ""
echo -e "${CYAN}[*] Recomendado (una vez): registra los nombres en /etc/hosts:${NC}"
echo -e "      sudo ./recon-hosts.sh        # luego: nmap alpha, curl http://bravo/ ..."
echo -e "${CYAN}[*] Recon raw (-sS/-sU/-O/hping3) requiere privilegios -> usa sudo.${NC}"
echo -e "${CYAN}[*] Empieza por la Misión 01:${NC}  nmap -sn 172.30.0.0/24"
echo ""
echo -e "${YEL}[i] Consola opcional con todo preinstalado (no necesaria):${NC}"
echo -e "      docker compose --profile tools up -d attacker && docker compose exec attacker bash"
