# Scoreboard CTF — "Operación Red Recon"
# Plataforma de gamificación (Flask + gunicorn + SQLite).
# Contexto de build = raíz del repo (ver docker-compose.yml).
FROM python:3.12-slim

# No generar .pyc y volcar logs sin buffer (mejor para contenedores).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Instalar dependencias primero para aprovechar la caché de capas.
COPY scoreboard/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copiar la aplicación y sus recursos (rutas relativas a la raíz del repo).
COPY scoreboard/app.py /app/app.py
COPY scoreboard/reset_db.py /app/reset_db.py
COPY scoreboard/challenges.yml /app/challenges.yml
COPY scoreboard/templates /app/templates
COPY scoreboard/static /app/static

# Directorio del volumen de datos (SQLite). El volumen se monta en runtime.
RUN mkdir -p /data

# Puerto interno del servicio (compose lo publica como 8080 en el host).
EXPOSE 8000

# Servidor de producción: 2 workers, escuchando en todas las interfaces.
CMD ["gunicorn", "-b", "0.0.0.0:8000", "-w", "2", "--access-logfile", "-", "app:create_app()"]
