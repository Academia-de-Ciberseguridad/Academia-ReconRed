# =============================================================================
# Objetivo ECHO (172.30.0.25) — Deteccion de SO / TTL (NET_ADMIN)
# Proposito didactico: ensenar "nmap -O" y la inferencia de SO por TTL, ASI COMO
# SUS LIMITES en contenedores: todos comparten el kernel del host, de modo que
# el fingerprint real de -O delata al kernel Linux del host, no a "Windows".
# Por eso aqui la pista util es el TTL de salida forzado a 128 (tipico Windows).
#
# Servicios "Windows-like" expuestos (portsrv, banners):
#   135/tcp  -> banner msrpc-like   (Microsoft RPC)
#   139/tcp  -> banner netbios-like (NetBIOS Session Service)
#   445/tcp  -> banner SMB-like CON el flag de M08
#
# TTL de salida forzado a 128 via iptables mangle (lo aplica entrypoint.sh).
# Requiere cap NET_ADMIN (ya definida en compose) para tocar la tabla mangle.
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM debian:bookworm-slim

# iptables (para reescribir el TTL en la tabla mangle) y python3 (motor de
# portsrv). Limpiamos las listas de apt para una imagen pequena y un build rapido.
RUN apt-get update \
    && apt-get install -y --no-install-recommends iptables python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Simulador multipuerto compartido y su configuracion especifica de echo.
COPY targets/common/portsrv.py /opt/portsrv.py
COPY targets/echo/portsrv.json /etc/portsrv.json

# Nota para el instructor: limites de -O en contenedores e inferencia por TTL.
COPY targets/echo/recon-note.txt /etc/recon-note.txt

# Script de arranque: fuerza el TTL de salida a 128 (mangle) y deja portsrv.py
# en primer plano para mantener vivo el contenedor.
COPY targets/echo/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Puertos "Windows-like" que abre portsrv para sugerir el SO al alumno.
EXPOSE 135 139 445

ENTRYPOINT ["/entrypoint.sh"]
