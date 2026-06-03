# Operación Red Recon — atajos de gestión del laboratorio
# Uso: make help

COMPOSE := docker compose

.PHONY: help up build down stop start restart shell scoreboard logs ps reset nuke status targets check

help:               ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: build           ## Construye (si hace falta) y levanta todo el laboratorio
	$(COMPOSE) up -d
	@echo ""
	@echo "  [+] Laboratorio ARRIBA."
	@echo "  [+] Scoreboard:  http://localhost:8080"
	@echo "  [+] Consola:     make shell   (o: docker compose exec attacker bash)"
	@echo ""

build:              ## Construye todas las imágenes
	$(COMPOSE) build

down:               ## Para y elimina contenedores y red (conserva datos del scoreboard)
	$(COMPOSE) down

stop:               ## Detiene los contenedores sin eliminarlos
	$(COMPOSE) stop

start:              ## Arranca contenedores ya creados
	$(COMPOSE) start

restart:            ## Reinicia todo el laboratorio
	$(COMPOSE) restart

hosts:              ## Registra los nombres de los objetivos en /etc/hosts (usa sudo)
	sudo ./recon-hosts.sh

tools:              ## (Opcional) Levanta el contenedor atacante con todo preinstalado
	$(COMPOSE) --profile tools up -d attacker
	@echo "  [+] Estación atacante lista. Entra con: make shell"

shell:              ## (Opcional) Abre una shell en la estación atacante (la levanta si hace falta)
	$(COMPOSE) --profile tools up -d attacker
	$(COMPOSE) exec attacker bash

scoreboard:         ## Abre el scoreboard en el navegador (Linux)
	@xdg-open http://localhost:8080 >/dev/null 2>&1 || echo "Abre http://localhost:8080"

logs:               ## Sigue los logs de todos los servicios
	$(COMPOSE) logs -f

ps status:          ## Estado de los contenedores
	$(COMPOSE) ps

targets:            ## Lista las IPs de los objetivos
	@echo "  scoreboard 172.30.0.5    attacker 172.30.0.10"
	@echo "  alpha 172.30.0.21  bravo 172.30.0.22  charlie 172.30.0.23"
	@echo "  delta 172.30.0.24  echo  172.30.0.25  foxtrot 172.30.0.26"
	@echo "  hotel 172.30.0.27"

reset:              ## Reinicia el progreso del scoreboard (borra puntuaciones)
	$(COMPOSE) exec scoreboard python3 /app/reset_db.py || \
	  echo "Levanta el scoreboard primero (make up)."

check:              ## Valida la sintaxis del docker-compose
	$(COMPOSE) config -q && echo "  [+] docker-compose.yml OK"

nuke:               ## Elimina TODO (contenedores, red, volúmenes, imágenes del lab)
	$(COMPOSE) down -v --rmi local
