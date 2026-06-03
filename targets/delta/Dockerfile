# =============================================================================
# Objetivo DELTA (172.30.0.24) — Ruido/decoys/timing
# Proposito didactico: ensenar rendimiento y timing (-T0..-T5), --top-ports,
# rangos de puertos (-p) y separar la SENAL del RUIDO.
#
# Diseno:
#   - 9000-9049/tcp → 50 decoys identicos (portsrv, banner generico)
#   - 9042/tcp     → unico puerto real/distinto: banner con el flag de M07
#                    (9042 esta dentro del rango pero su entrada concreta gana)
#
# Contexto de build = raiz del repo (las rutas COPY son relativas a la raiz).
# =============================================================================
FROM python:3.12-slim

# Simulador multipuerto compartido (solo stdlib) y la configuracion de delta.
COPY targets/common/portsrv.py /opt/portsrv.py
COPY targets/delta/portsrv.json /etc/portsrv.json

# Script de arranque: deja portsrv.py en primer plano (mantiene vivo el contenedor).
COPY targets/delta/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 9000-9049 = 50 decoys identicos; 9042 = el unico servicio real (flag M07).
EXPOSE 9000-9049

ENTRYPOINT ["/entrypoint.sh"]
