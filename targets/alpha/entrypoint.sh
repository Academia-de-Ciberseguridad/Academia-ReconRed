#!/bin/bash
# =============================================================================
# entrypoint.sh — Objetivo ALPHA (172.30.0.21)
# Arranca OpenSSH real en segundo plano y deja nginx en primer plano
# para que el contenedor permanezca vivo.
# =============================================================================
set -e

# --- SSH: generar claves de host si no existen ---------------------------
# ssh-keygen -A crea las claves de host que falten. Sin ellas, sshd no arranca
# y nmap -sV no podria leer el banner de version de OpenSSH.
ssh-keygen -A

# Endurecimiento minimo y didactico: NO queremos acceso real, solo el banner.
# Deshabilitamos por completo el login (sin password y sin root login).
# El objetivo del laboratorio es exponer el banner de version, no dar shell.
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/'            /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication no/'  /etc/ssh/sshd_config

# Arrancar sshd en segundo plano (-e envia logs a stderr, util en contenedor).
# La separacion de privilegios usa el usuario 'sshd' que ya existe en Alpine.
/usr/sbin/sshd -e

# --- nginx: proceso en primer plano (mantiene vivo el contenedor) --------
# "daemon off;" hace que nginx no se demonice y sea el proceso principal.
exec nginx -g "daemon off;"
