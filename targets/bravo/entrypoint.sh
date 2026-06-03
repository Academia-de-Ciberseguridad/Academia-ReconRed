#!/bin/sh
# =============================================================================
# entrypoint.sh — Objetivo BRAVO (172.30.0.22)
# Proposito didactico: deteccion de version -sV e INTERACCION con un servicio
# real (redis) para extraer un flag (mision M04).
#
# Arranca redis-server en segundo plano, siembra las claves del reto y deja
# portsrv.py en primer plano sirviendo los banners simulados de MySQL/PostgreSQL,
# de modo que el contenedor permanezca vivo.
# =============================================================================
set -e

# --- redis: servicio REAL (puerto 6379) ----------------------------------
# Lo arrancamos como demonio en segundo plano. Es un laboratorio aislado:
#   --bind 0.0.0.0      escucha en todas las interfaces (accesible desde attacker)
#   --protected-mode no permite conexiones remotas sin password (didactico)
#   --daemonize yes     se demoniza para devolver el control al script
redis-server --bind 0.0.0.0 --protected-mode no --daemonize yes

# Damos un instante a redis para abrir el socket antes de escribir las claves.
sleep 1

# --- Siembra del reto (M04) ----------------------------------------------
# El alumno debe interactuar con redis (redis-cli -h bravo GET flag) para
# recuperar el flag. Dejamos tambien una pista en la clave "pista".
redis-cli set flag "RECON{r3d1s_k3y_l00t3d}"
redis-cli set pista "Bien hecho. Reporta el valor de la clave flag en el scoreboard (M04)."

# --- portsrv: proceso en primer plano (mantiene vivo el contenedor) ------
# Sirve los banners simulados de MySQL (3306) y PostgreSQL (5432) para -sV.
exec python3 /opt/portsrv.py
