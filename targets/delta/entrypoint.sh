#!/bin/sh
# =============================================================================
# entrypoint.sh — Objetivo DELTA (172.30.0.24)
# Proposito didactico: rendimiento y timing (-T0..-T5), --top-ports, rangos -p
# y, sobre todo, separar la SENAL del RUIDO.
#
# Diseno: ~50 puertos decoy identicos (9000-9049) mas un unico puerto real
# distinto (9042) que esconde el flag de la mision M07. El gran numero de
# puertos abiertos hace lento un -sV ingenuo; el alumno debe acotar el ruido.
#
# No hay servicios reales que arrancar aqui: portsrv.py simula todos los
# puertos y se queda en primer plano para mantener vivo el contenedor.
# =============================================================================
set -e

# --- portsrv: proceso en primer plano (mantiene vivo el contenedor) ------
# Sirve los 50 banners decoy identicos y el banner distintivo de 9042.
exec python3 /opt/portsrv.py
