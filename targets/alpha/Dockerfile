# =============================================================================
# Objetivo ALPHA (172.30.0.21) — Web + SSH reales
# Proposito didactico: host discovery, escaneo -sT/-sS, deteccion de version -sV
# (servicios REALES) y banner grabbing.
#
# Servicios expuestos:
#   - 22/tcp   OpenSSH real (banner de version para nmap -sV)
#   - 80/tcp   nginx real (web principal + /robots.txt + cabecera X-Recon-Flag)
#   - 8080/tcp nginx "panel" (vhost con la pista de la version del servidor)
#
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM nginx:alpine

# OpenSSH server real (para banner de version) y bash para el entrypoint.
# Limpieza de la cache de apk para mantener la imagen pequena y el build rapido.
RUN apk add --no-cache openssh bash \
    && rm -rf /var/cache/apk/*

# Configuracion de nginx: dos server{} -> :80 (web principal) y :8080 (panel).
COPY targets/alpha/nginx.conf /etc/nginx/nginx.conf

# Contenido web servido por cada vhost.
COPY targets/alpha/www/   /usr/share/nginx/html/
COPY targets/alpha/panel/ /usr/share/nginx/panel/

# Script de arranque: genera claves host SSH, lanza sshd en segundo plano
# y deja nginx en primer plano para mantener vivo el contenedor.
COPY targets/alpha/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 22 = OpenSSH, 80 = web principal, 8080 = panel nginx.
EXPOSE 22 80 8080

ENTRYPOINT ["/entrypoint.sh"]
