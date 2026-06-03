#!/bin/sh
# =============================================================================
# entrypoint.sh — Objetivo CHARLIE (172.30.0.23)
# Proposito didactico: ensenar la diferencia OPEN / CLOSED / FILTERED, el uso
# de -Pn, de nmap --reason y del ACK scan (-sA), apoyandose en iptables.
#
# Mapa de estados que produce este contenedor:
#   22/tcp    OPEN     -> portsrv escucha (banner SSH-like).
#   31337/tcp OPEN     -> portsrv escucha; banner con el flag de M05 (oculto).
#   80/tcp    CLOSED   -> nadie escucha y SIN regla -> el kernel responde RST.
#   443/tcp   FILTERED -> iptables DROP en INPUT (sin respuesta).
#   8000/tcp  FILTERED -> iptables DROP (ruido para practicar --reason).
#   3389/tcp  FILTERED -> iptables DROP (ruido).
#   5900/tcp  FILTERED -> iptables DROP (ruido).
#
# Cada regla se aplica con "|| true" y un aviso si falla, de modo que el
# contenedor arranque igualmente aunque iptables no este disponible. Finalmente
# se cede el control a portsrv.py en primer plano para mantener vivo el PID 1.
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
    echo "[charlie] backend iptables operativo: $IPT"
else
    echo "[charlie] AVISO: no hay backend iptables operativo; los puertos FILTERED no se aplicaran."
fi

# --- Helper: aplica un DROP en INPUT para un puerto TCP ------------------
# Marca el puerto como FILTERED (sin respuesta). Tolera fallos para no abortar
# el arranque del contenedor (entornos sin NET_ADMIN o sin modulos cargados).
drop_tcp() {
    puerto="$1"
    if [ -n "$IPT" ]; then
        if "$IPT" -A INPUT -p tcp --dport "$puerto" -j DROP 2>/dev/null; then
            echo "[charlie] FILTERED: DROP aplicado a ${puerto}/tcp"
        else
            echo "[charlie] AVISO: no se pudo aplicar DROP a ${puerto}/tcp (se continua igualmente)" || true
        fi
    fi
}

# --- Reglas de cortafuegos: puertos FILTERED -----------------------------
# 443  = el puerto "estrella" de la leccion (estado filtered -> respuesta M06).
# 8000, 3389, 5900 = ruido adicional para practicar nmap --reason.
# IMPORTANTE: NO se toca el 80 -> permanece CLOSED (RST del kernel).
drop_tcp 443  || true
drop_tcp 8000 || true
drop_tcp 3389 || true
drop_tcp 5900 || true

# --- portsrv: proceso en primer plano (mantiene vivo el contenedor) ------
# Abre 22 (banner SSH-like) y 31337 (banner con el flag). El 80 no se abre,
# por lo que el kernel responde RST y nmap lo vera como CLOSED.
exec python3 /opt/portsrv.py
