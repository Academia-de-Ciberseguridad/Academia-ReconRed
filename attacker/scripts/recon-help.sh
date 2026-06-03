#!/usr/bin/env bash
# recon-help — chuleta de comandos de reconocimiento para Operación Red Recon.
# Estación del atacante. Solo referencia didáctica; nada de esto se ejecuta.
set -euo pipefail

# Colores (se desactivan si la salida no es un terminal).
if [ -t 1 ]; then
    C_TITLE='\033[1;32m'   # verde negrita
    C_SECT='\033[1;36m'    # cian negrita
    C_CMD='\033[0;33m'     # amarillo
    C_DIM='\033[0;90m'     # gris
    C_OFF='\033[0m'
else
    C_TITLE='' ; C_SECT='' ; C_CMD='' ; C_DIM='' ; C_OFF=''
fi

printf "${C_TITLE}=== OPERACION RED RECON — CHULETA DE COMANDOS ===${C_OFF}\n"
printf "${C_DIM}Subred del lab: 172.30.0.0/24   |   Tú eres attacker = 172.30.0.10${C_OFF}\n\n"

printf "${C_SECT}[1] DESCUBRIMIENTO DE HOSTS (host discovery)${C_OFF}\n"
printf "  ${C_CMD}nmap -sn 172.30.0.0/24${C_OFF}            barrido ping: ¿qué hosts están vivos?\n"
printf "  ${C_CMD}sweep${C_OFF}                             alias del barrido anterior\n"
printf "  ${C_CMD}nmap -sn -PR 172.30.0.0/24${C_OFF}        descubrimiento por ARP (red local)\n\n"

printf "${C_SECT}[2] ESCANEO DE PUERTOS${C_OFF}\n"
printf "  ${C_CMD}nmap -sT 172.30.0.21${C_OFF}              TCP connect (no requiere privilegios)\n"
printf "  ${C_CMD}nmap -sS 172.30.0.21${C_OFF}              SYN scan / 'sigiloso' (usa NET_RAW)\n"
printf "  ${C_CMD}nmap -sU 172.30.0.26${C_OFF}              UDP scan (lento; prueba foxtrot)\n"
printf "  ${C_CMD}nmap -p- 172.30.0.24${C_OFF}              los 65535 puertos (aguja en el pajar)\n"
printf "  ${C_CMD}nmap -p 22,80,443 172.30.0.23${C_OFF}     puertos concretos (estados de puerto)\n\n"

printf "${C_SECT}[3] VERSIÓN Y SISTEMA OPERATIVO${C_OFF}\n"
printf "  ${C_CMD}nmap -sV 172.30.0.21${C_OFF}              detección de versión de servicios\n"
printf "  ${C_CMD}nmap -sV --version-all 172.30.0.22${C_OFF} sondeo de versión exhaustivo (bravo)\n"
printf "  ${C_CMD}nmap -O 172.30.0.25${C_OFF}               detección de SO por huella (echo/TTL)\n"
printf "  ${C_CMD}nmap -A 172.30.0.21${C_OFF}               agresivo: -sV + -O + scripts + traceroute\n\n"

printf "${C_SECT}[4] NSE (Nmap Scripting Engine)${C_OFF}\n"
printf "  ${C_CMD}nmap -sC 172.30.0.21${C_OFF}              scripts 'default' (rápido y seguro)\n"
printf "  ${C_CMD}nmap --script http-headers -p80 172.30.0.21${C_OFF}  cabeceras HTTP (busca X-Recon-Flag)\n"
printf "  ${C_CMD}nmap --script banner -p- 172.30.0.24${C_OFF}         captura banners de cada puerto\n"
printf "  ${C_CMD}nmap -sU --script dns-recursion -p53 172.30.0.26${C_OFF}  pruebas DNS/UDP\n\n"

printf "${C_SECT}[5] hping3 — CABECERAS TCP A MANO (objetivo hotel)${C_OFF}\n"
printf "  ${C_CMD}hping3 -S -p 22 -c 3 172.30.0.27${C_OFF}  envía SYN → puerto abierto responde SYN/ACK\n"
printf "  ${C_CMD}hping3 -A -p 80 -c 3 172.30.0.27${C_OFF}  envía ACK → observa flags de respuesta\n"
printf "  ${C_CMD}hping3 -F -p 443 -c 3 172.30.0.27${C_OFF} envía FIN → filtrado: sin respuesta\n"
printf "  ${C_CMD}hping3 -S -p 7777 -c 3 172.30.0.27${C_OFF} explora puertos altos (recompensa)\n"
printf "  ${C_DIM}Flags: -S SYN  -A ACK  -F FIN  -R RST  -P PSH  -U URG  | -V verbose (win,ttl)${C_OFF}\n\n"

printf "${C_SECT}[6] DNS / WHOIS / INTERACCIÓN${C_OFF}\n"
printf "  ${C_CMD}dig @172.30.0.26 flag.recon.lab TXT${C_OFF}    registro TXT con el flag (foxtrot)\n"
printf "  ${C_CMD}dig @172.30.0.26 recon.lab ANY${C_OFF}         enumera la zona recon.lab\n"
printf "  ${C_CMD}redis-cli -h 172.30.0.22 GET flag${C_OFF}      lee la clave 'flag' en bravo\n"
printf "  ${C_CMD}curl -i http://172.30.0.21/robots.txt${C_OFF}  inspecciona robots.txt (alpha)\n"
printf "  ${C_CMD}whois 172.30.0.21${C_OFF}                      (referencia; red privada)\n\n"

printf "${C_SECT}[7] EVASIÓN (objetivos charlie / hotel)${C_OFF}\n"
printf "  ${C_CMD}nmap -g 53 -sS 172.30.0.23${C_OFF}        puerto origen 53 para atravesar reglas\n"
printf "  ${C_CMD}nmap --source-port 53 172.30.0.27${C_OFF} idem (--source-port == -g)\n"
printf "  ${C_CMD}nmap -f 172.30.0.23${C_OFF}               fragmenta los paquetes\n\n"

# Tabla de objetivos compartida con recon-targets.
if command -v recon-targets >/dev/null 2>&1; then
    recon-targets
fi

printf "${C_DIM}Scoreboard: http://localhost:8080 (host) | http://172.30.0.5:8000 (interno)${C_OFF}\n"
printf "${C_DIM}Guarda tus notas y volcados en /labs (ver /labs/README.md).${C_OFF}\n"
