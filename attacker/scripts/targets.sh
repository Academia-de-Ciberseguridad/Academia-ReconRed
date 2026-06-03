#!/usr/bin/env bash
# recon-targets — tabla de objetivos del laboratorio Operación Red Recon.
# Solo imprime la lista de IPs/roles; no toca la red.
set -euo pipefail

if [ -t 1 ]; then
    C_TITLE='\033[1;32m'   # verde negrita
    C_HEAD='\033[1;36m'    # cian negrita
    C_DIM='\033[0;90m'     # gris
    C_OFF='\033[0m'
else
    C_TITLE='' ; C_HEAD='' ; C_DIM='' ; C_OFF=''
fi

printf "${C_TITLE}=== OBJETIVOS — Operación Red Recon (red 172.30.0.0/24) ===${C_OFF}\n"
printf "${C_HEAD}%-9s %-14s %s${C_OFF}\n" "HOST" "IP" "ROL / PISTA"
printf "%-9s %-14s %s\n" "alpha"   "172.30.0.21" "Web + SSH reales (-sT/-sS/-sV; robots.txt, X-Recon-Flag)"
printf "%-9s %-14s %s\n" "bravo"   "172.30.0.22" "Detección de versión + redis (redis-cli GET flag)"
printf "%-9s %-14s %s\n" "charlie" "172.30.0.23" "Estados de puerto: open/closed/filtered (firewall)"
printf "%-9s %-14s %s\n" "delta"   "172.30.0.24" "Ruido/decoys/timing (~50 puertos + 1 real)"
printf "%-9s %-14s %s\n" "echo"    "172.30.0.25" "Detección de SO por TTL (-O)"
printf "%-9s %-14s %s\n" "foxtrot" "172.30.0.26" "UDP scanning + DNS/NSE (-sU, dig TXT)"
printf "%-9s %-14s %s\n" "hotel"   "172.30.0.27" "hping3 + cabeceras TCP (SYN/ACK/FIN, win, TTL)"
printf "\n"
printf "${C_DIM}Infraestructura (no son 'objetivos' de las misiones de mapeo):${C_OFF}\n"
printf "${C_DIM}%-9s %-14s %s${C_OFF}\n" "scoreboard" "172.30.0.5"  "Plataforma CTF — http://localhost:8080 (host) / :8000 (interno)"
printf "${C_DIM}%-9s %-14s %s${C_OFF}\n" "attacker"   "172.30.0.10" "Tú estás aquí (esta estación)"
printf "\n"
