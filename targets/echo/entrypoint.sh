#!/bin/sh
# =============================================================================
# entrypoint.sh — Objetivo ECHO (172.30.0.25)
# Proposito didactico: ensenar "nmap -O" / inferencia de SO por TTL y SUS
# LIMITES en contenedores (kernel compartido con el host).
#
# Que hace este contenedor:
#   - Abre 135/139/445 con banners "Windows-like" (lo hace portsrv).
#   - Fuerza el TTL de TODO el trafico de salida a 128 (tipico de Windows)
#     reescribiendolo en la tabla mangle de iptables. Asi, aunque "nmap -O"
#     fingerprintee el kernel Linux del host, la inferencia por TTL apunta a
#     Windows -> respuesta de M08 = "windows".
#
# La regla se aplica con "|| true" y un aviso si falla, de modo que el
# contenedor arranque igualmente aunque iptables/mangle no esten disponibles
# (entornos sin NET_ADMIN o sin el modulo cargado). Finalmente se cede el
# control a portsrv.py en primer plano para mantener vivo el PID 1.
# =============================================================================
set -e

# --- Seleccion de un backend de iptables QUE FUNCIONE --------------------
# OJO: en kernels modernos el host usa nf_tables y el backend "legacy" existe
# como binario pero FALLA en runtime ("Table does not exist"). Por eso no basta
# con `command -v`: probamos cada candidato listando la tabla 'mangle' y nos
# quedamos con el primero que responda sin error (preferimos el wrapper nft).
IPT=""
for cand in iptables-nft iptables iptables-legacy; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -t mangle -nL >/dev/null 2>&1; then
        IPT="$cand"
        break
    fi
done
if [ -n "$IPT" ]; then
    echo "[echo] backend iptables operativo: $IPT"
else
    echo "[echo] AVISO: no hay backend iptables operativo; el TTL de salida NO se forzara a 128."
fi

# --- Forzar TTL de salida a 128 (simular Windows) ------------------------
# El target TTL de la tabla mangle reescribe el campo TTL de cada paquete que
# sale del contenedor. 128 es el valor inicial tipico de Windows; combinado con
# los banners SMB/NetBIOS, hace que la inferencia por TTL apunte a "windows".
if [ -n "$IPT" ]; then
    if "$IPT" -t mangle -A OUTPUT -j TTL --ttl-set 128 2>/dev/null; then
        echo "[echo] TTL de salida forzado a 128 (mangle OUTPUT) -> apariencia Windows."
    else
        echo "[echo] AVISO: no se pudo forzar TTL=128 (falta NET_ADMIN o el modulo TTL); se continua igualmente." || true
    fi
fi

# --- portsrv: proceso en primer plano (mantiene vivo el contenedor) ------
# Abre 135 (msrpc-like), 139 (netbios-like) y 445 (SMB-like con el flag M08).
exec python3 /opt/portsrv.py
