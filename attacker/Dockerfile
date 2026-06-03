# Operación Red Recon — estación del ATACANTE
# Contexto de build = raíz del repo (ver docker-compose.yml).
# Estación puramente ofensiva: NO levanta ningún servidor.
# El alumno entra con:  docker compose exec attacker bash
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="recon-lab attacker" \
      org.opencontainers.image.description="Estación ofensiva (nmap/hping3/scapy) de Operación Red Recon" \
      org.opencontainers.image.vendor="Academia de Ciberseguridad — laboratorio educativo aislado"

# Evita preguntas interactivas de apt durante el build.
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Herramientas de reconocimiento y red. Sin recomendados, limpiando listas
# de apt en la misma capa para mantener la imagen pequeña y reproducible.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        nmap \
        hping3 \
        python3 \
        python3-scapy \
        tcpdump \
        netcat-openbsd \
        ncat \
        masscan \
        iputils-ping \
        dnsutils \
        curl \
        wget \
        iproute2 \
        net-tools \
        whois \
        redis-tools \
        less \
        vim-tiny \
        git \
        ca-certificates \
        bash \
        procps \
        grep \
        gawk \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# --- Material de apoyo de la estación ---------------------------------------
# Banner de bienvenida (objetivos, scoreboard, quickstart).
COPY attacker/motd /etc/motd

# Chuletas y helpers, instalados en el PATH del alumno.
COPY attacker/scripts/recon-help.sh /usr/local/bin/recon-help
COPY attacker/scripts/targets.sh    /usr/local/bin/recon-targets
RUN chmod +x /usr/local/bin/recon-help /usr/local/bin/recon-targets

# Personalización de la shell (motd, alias, prompt con tema "hacker").
# Se añade tanto al .bashrc de root como al bash.bashrc global, para que
# cualquier shell interactiva (login o no) herede la configuración.
COPY attacker/bashrc-extra /etc/recon-bashrc-extra
RUN cat /etc/recon-bashrc-extra >> /root/.bashrc \
 && cat /etc/recon-bashrc-extra >> /etc/bash.bashrc

# Carpeta de trabajo del alumno para guardar notas y volcados de escaneos.
COPY attacker/labs-readme.md /labs/README.md

WORKDIR /root

# El contenedor se mantiene vivo en primer plano; el alumno entra con
# `docker compose exec attacker bash`. compose le concede NET_RAW/NET_ADMIN.
CMD ["sleep", "infinity"]
