#!/bin/sh
# =============================================================================
# entrypoint.sh — Objetivo HOTEL (172.30.0.27)
# Proposito didactico: ensenar hping3 y las cabeceras TCP. El alumno envia
# paquetes SYN/ACK/FIN con hping3 y observa la respuesta segun el estado del
# puerto, analizando ademas TTL y window de las respuestas.
#
# Mapa de respuestas que produce este contenedor:
#   22/tcp    OPEN     -> portsrv en LISTEN; el kernel responde SYN/ACK al SYN.
#   7777/tcp  OPEN     -> portsrv en LISTEN; SYN/ACK + banner con el flag (M10).
#   80/tcp    CLOSED   -> nadie escucha y SIN regla -> el kernel responde RST.
#   443/tcp   FILTERED -> iptables DROP en INPUT -> sin respuesta.
#
# La regla iptables se aplica con "|| true" y un aviso si falla, de modo que el
# contenedor arranque igualmente aunque iptables no este disponible (entornos
# sin NET_ADMIN o sin modulos cargados). Finalmente se cede el control a
# portsrv.py en primer plano para mantener vivo el PID 1.
#
# Requiere cap NET_ADMIN (ya definida en compose) para aplicar iptables.
# =============================================================================
set -e

# --- Seleccion de un backend de iptables QUE FUNCIONE --------------------
# OJO: en kernels modernos el host usa nf_tables y el backend "legacy" existe
# como binario pero FALLA en runtime ("Table does not exist"). Por eso no basta
# con `command -v`: probamos cada candidato listando la tabla 'filter' y nos
# quedamos con el primero que responda sin error (preferimos el wrapper nft).
IPT=""
for cand in iptables-nft iptables iptables-legacy; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -t filter -nL >/dev/null 2>&1; then
        IPT="$cand"
        break
    fi
done
if [ -n "$IPT" ]; then
    echo "[hotel] backend iptables operativo: $IPT"
else
    echo "[hotel] AVISO: no hay backend iptables operativo; el puerto FILTERED no se aplicara."
fi

# --- Regla de cortafuegos: 443/tcp FILTERED ------------------------------
# DROP en INPUT -> el paquete se descarta sin respuesta. hping3 -S/-A/-F contra
# 443 no recibira nada (sin SYN/ACK ni RST): asi se ve la diferencia entre
# CLOSED (RST) y FILTERED (silencio). Toleramos fallos para no abortar el
# arranque del contenedor.
if [ -n "$IPT" ]; then
    if "$IPT" -A INPUT -p tcp --dport 443 -j DROP 2>/dev/null; then
        echo "[hotel] FILTERED: DROP aplicado a 443/tcp (sin respuesta)"
    else
        echo "[hotel] AVISO: no se pudo aplicar DROP a 443/tcp (se continua igualmente)" || true
    fi
fi

# IMPORTANTE: NO se toca el 80 -> permanece CLOSED. Al no haber proceso en
# LISTEN ni regla iptables, el kernel responde RST: hping3 lo vera como cerrado.

# --- portsrv: proceso en primer plano (mantiene vivo el contenedor) ------
# Abre 22 (banner SSH-like) y 7777 (banner con el flag). Ambos quedan en LISTEN,
# por lo que el kernel responde SYN/ACK al SYN entrante de hping3.
exec python3 /opt/portsrv.py
