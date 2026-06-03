# =============================================================================
# Objetivo FOXTROT (172.30.0.26) — UDP + DNS/NSE
# Proposito didactico: ensenar escaneo UDP (-sU y por que es lento), DNS y NSE
# (scripts dns-*) y la extraccion de un registro TXT con el flag de M09.
#
# Servicios:
#   53/udp + 53/tcp -> dnsmasq REAL. Zona recon.lab. TXT flag.recon.lab con el
#                      flag de M09 y varios A records de practica.
#   123/udp         -> banner NTP-like  (portsrv, proto udp)
#   161/udp         -> banner SNMP-like (portsrv, proto udp; community 'public')
#
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM debian:bookworm-slim

# dnsmasq (servidor DNS real), python3 (motor de portsrv) y dnsutils (aporta
# nslookup/dig para la comprobacion de arranque). Limpiamos las cachas de apt
# para una imagen pequena y un build rapido y fiable.
RUN apt-get update \
    && apt-get install -y --no-install-recommends dnsmasq python3 dnsutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Simulador multipuerto compartido y su configuracion especifica de foxtrot
# (solo los puertos UDP 'extra': 123 y 161; el 53 lo sirve dnsmasq).
COPY targets/common/portsrv.py /opt/portsrv.py
COPY targets/foxtrot/portsrv.json /etc/portsrv.json

# Configuracion de dnsmasq: zona recon.lab, TXT del flag y A records de practica.
COPY targets/foxtrot/dnsmasq.conf /etc/dnsmasq.conf

# Script de arranque: lanza dnsmasq en segundo plano (53 udp/tcp en 0.0.0.0) y
# deja portsrv.py en primer plano para mantener vivo el contenedor.
COPY targets/foxtrot/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# DNS (udp y tcp) y los dos puertos UDP didacticos (NTP-like / SNMP-like).
EXPOSE 53/udp 53/tcp 123/udp 161/udp

ENTRYPOINT ["/entrypoint.sh"]
