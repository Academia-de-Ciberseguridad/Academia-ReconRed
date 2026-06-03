#!/bin/sh
# =============================================================================
# entrypoint.sh — Objetivo FOXTROT (172.30.0.26)
# Proposito didactico: escaneo UDP (-sU y por que es lento), DNS y NSE (dns-*)
# y la extraccion de un registro TXT con el flag de la mision M09.
#
# Que hace este contenedor:
#   - Arranca dnsmasq REAL en segundo plano: zona recon.lab, registro TXT con
#     el flag (flag.recon.lab) y varios A records de practica. Escucha 53 en
#     udp y tcp sobre 0.0.0.0.
#   - Deja portsrv.py en primer plano sirviendo los puertos UDP "extra":
#     123/udp (NTP-like) y 161/udp (SNMP-like). Asi el PID 1 se mantiene vivo.
#
# El flag de M09 se obtiene con:
#   dig @172.30.0.26 flag.recon.lab TXT
#   nmap -sU -p53 --script dns-* 172.30.0.26
# =============================================================================
set -e

CONF="/etc/dnsmasq.conf"

# --- Validacion de la configuracion de dnsmasq -------------------------------
# --test comprueba la sintaxis del fichero antes de arrancar; si falla, mejor
# enterarse aqui que con un contenedor "vivo" pero sin DNS.
echo "[foxtrot] Validando configuracion de dnsmasq..."
dnsmasq --test --conf-file="$CONF"

# --- Arranque de dnsmasq en segundo plano ------------------------------------
# --keep-in-foreground + '&' nos permite lanzarlo controladamente y conservar el
# control del script (el primer plano real sera portsrv.py).
# --log-queries y --no-daemon-style logging ya vienen del fichero de conf.
echo "[foxtrot] Arrancando dnsmasq (DNS real, zona recon.lab) en segundo plano..."
dnsmasq --keep-in-foreground --conf-file="$CONF" &
DNS_PID=$!

# --- Espera activa: confirmar que el 53/udp esta listo -----------------------
# Reintentamos unas cuantas veces una consulta local del registro TXT del flag.
# Si responde, damos por bueno el arranque; si no, avisamos pero continuamos
# (el contenedor debe quedarse vivo igualmente para fines de laboratorio).
echo "[foxtrot] Esperando a que dnsmasq responda en 127.0.0.1:53..."
READY=0
i=1
while [ "$i" -le 10 ]; do
    # nslookup (de dnsutils) consulta el TXT del flag contra el propio servidor.
    if nslookup -type=TXT flag.recon.lab 127.0.0.1 >/dev/null 2>&1; then
        READY=1
        break
    fi
    # Si el proceso de dnsmasq ya no existe, no tiene sentido seguir esperando.
    if ! kill -0 "$DNS_PID" 2>/dev/null; then
        echo "[foxtrot] AVISO: el proceso dnsmasq termino de forma inesperada."
        break
    fi
    sleep 1
    i=$((i + 1))
done

if [ "$READY" -eq 1 ]; then
    echo "[foxtrot] dnsmasq operativo: 53/udp+tcp respondiendo (TXT flag.recon.lab)."
else
    echo "[foxtrot] AVISO: no se confirmo respuesta de dnsmasq; se continua igualmente."
fi

# --- portsrv: proceso en primer plano (mantiene vivo el contenedor) ----------
# Sirve 123/udp (NTP-like) y 161/udp (SNMP-like). Es el PID 1 efectivo.
echo "[foxtrot] Cediendo el primer plano a portsrv.py (123/udp NTP-like, 161/udp SNMP-like)..."
exec python3 /opt/portsrv.py
