# =============================================================================
# Objetivo BRAVO (172.30.0.22) — Deteccion de version + interaccion (redis)
# Proposito didactico: nmap -sV e INTERACCION con redis real para extraer el
# flag de la mision M04 (redis-cli -h bravo GET flag).
#
# Servicios expuestos:
#   - 6379/tcp redis REAL (clave "flag" con el flag de M04, sin password)
#   - 3306/tcp banner MySQL simulado (portsrv) para -sV
#   - 5432/tcp banner PostgreSQL simulado (portsrv) para -sV
#
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM redis:7-alpine

# python3 para ejecutar el simulador de banners portsrv (solo stdlib).
# Limpieza de la cache de apk para mantener la imagen pequena y el build rapido.
RUN apk add --no-cache python3 \
    && rm -rf /var/cache/apk/*

# Simulador multipuerto compartido y su configuracion especifica de bravo.
COPY targets/common/portsrv.py /opt/portsrv.py
COPY targets/bravo/portsrv.json /etc/portsrv.json

# Script de arranque: lanza redis en segundo plano, siembra el flag y deja
# portsrv.py en primer plano para mantener vivo el contenedor.
COPY targets/bravo/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 6379 = redis real, 3306 = banner MySQL, 5432 = banner PostgreSQL.
EXPOSE 6379 3306 5432

ENTRYPOINT ["/entrypoint.sh"]
