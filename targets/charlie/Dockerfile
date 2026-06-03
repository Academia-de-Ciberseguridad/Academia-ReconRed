# =============================================================================
# Objetivo CHARLIE (172.30.0.23) — Estados de puerto / firewall (NET_ADMIN)
# Proposito didactico: ensenar la diferencia OPEN / CLOSED / FILTERED, el uso
# de -Pn, de nmap --reason y del ACK scan (-sA).
#
# Estados producidos:
#   22/tcp    OPEN     (portsrv, banner SSH-like)
#   31337/tcp OPEN     (portsrv, banner con el flag de M05, "oculto")
#   80/tcp    CLOSED   (nadie escucha y SIN regla -> el kernel responde RST)
#   443/tcp   FILTERED (iptables DROP)
#   8000/tcp  FILTERED (iptables DROP, ruido)
#   3389/tcp  FILTERED (iptables DROP, ruido)
#   5900/tcp  FILTERED (iptables DROP, ruido)
#
# Requiere cap NET_ADMIN (ya definida en compose) para aplicar iptables.
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM debian:bookworm-slim

# iptables (cortafuegos para los estados FILTERED) y python3 (motor de portsrv).
# Limpiamos las listas de apt para mantener la imagen pequena y el build rapido.
RUN apt-get update \
    && apt-get install -y --no-install-recommends iptables python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Simulador multipuerto compartido y su configuracion especifica de charlie.
COPY targets/common/portsrv.py /opt/portsrv.py
COPY targets/charlie/portsrv.json /etc/portsrv.json

# Nota para el instructor con el estado esperado de cada puerto.
COPY targets/charlie/recon-note.txt /etc/recon-note.txt

# Script de arranque: aplica las reglas iptables (FILTERED) y deja portsrv.py
# en primer plano para mantener vivo el contenedor.
COPY targets/charlie/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 22 = open, 31337 = open (flag). 80/443/8000/3389/5900 NO se exponen aqui:
# su estado (closed/filtered) lo determinan el kernel y las reglas iptables.
EXPOSE 22 31337

ENTRYPOINT ["/entrypoint.sh"]
