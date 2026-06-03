# =============================================================================
# Objetivo HOTEL (172.30.0.27) — hping3 / cabeceras TCP (NET_ADMIN)
# Proposito didactico: ensenar hping3 y las cabeceras TCP. El alumno envia
# paquetes SYN/ACK/FIN y observa la respuesta segun el estado del puerto
# (SYN/ACK, RST o silencio), y analiza TTL/window de las respuestas.
#
# Respuestas producidas:
#   22/tcp    OPEN     (portsrv en LISTEN -> kernel responde SYN/ACK)
#   7777/tcp  OPEN     (portsrv en LISTEN -> SYN/ACK + banner con el flag M10)
#   80/tcp    CLOSED   (nadie escucha y SIN regla -> el kernel responde RST)
#   443/tcp   FILTERED (iptables DROP -> sin respuesta)
#
# Requiere cap NET_ADMIN (ya definida en compose) para aplicar iptables.
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM debian:bookworm-slim

# iptables (para el estado FILTERED de 443) y python3 (motor de portsrv).
# Limpiamos las listas de apt para mantener la imagen pequena y el build rapido.
RUN apt-get update \
    && apt-get install -y --no-install-recommends iptables python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Simulador multipuerto compartido y su configuracion especifica de hotel.
COPY targets/common/portsrv.py /opt/portsrv.py
COPY targets/hotel/portsrv.json /etc/portsrv.json

# Nota para el instructor con la respuesta esperada de cada puerto.
COPY targets/hotel/recon-note.txt /etc/recon-note.txt

# Script de arranque: aplica la regla iptables (443 FILTERED) y deja portsrv.py
# en primer plano para mantener vivo el contenedor.
COPY targets/hotel/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 22 = open, 7777 = open (flag). 80 (closed) y 443 (filtered) NO se exponen:
# su comportamiento lo determinan el kernel y la regla iptables.
EXPOSE 22 7777

ENTRYPOINT ["/entrypoint.sh"]
