# 🛰️ Operación Red Recon — Laboratorio de Reconocimiento de Redes

Laboratorio Docker **autocontenido, aislado y gamificado** para enseñar reconocimiento
de redes a fondo: **nmap, hping3, cabeceras TCP/IP, estados de puerto, detección de
versión/SO, NSE, escaneo UDP y evasión de firewalls** — todo sobre objetivos reales
controlados, con un **scoreboard CTF propio** (rangos, misiones, pistas, insignias y
leaderboard).

> ⚠️ **Uso educativo en entorno aislado.** La red `172.30.0.0/24` es privada y no debe
> exponerse a Internet. Varios objetivos usan capacidades de red (`NET_ADMIN`, `NET_RAW`)
> para manipular iptables/TTL con fines didácticos. Escanea **solo** los objetivos de este lab.

---

## 🚀 Puesta en marcha — todo NATIVO desde tu Kali

El laboratorio está pensado para que escanees **directamente desde tu Kali** (no hace
falta ningún contenedor atacante): la red `172.30.0.0/24` es accesible desde el host.

```bash
cd recon-lab
./start.sh                       # construye y levanta objetivos + scoreboard
sudo ./recon-hosts.sh            # (una vez) registra los nombres alpha..hotel en /etc/hosts

# ¡A reconocer! (los escaneos SYN/UDP/OS y hping3 necesitan sudo)
nmap -sn 172.30.0.0/24           # Misión 01: descubrimiento de hosts
sudo nmap -sS -sV 172.30.0.21    # puertos + versiones de alpha
```

Abre el **scoreboard** en tu navegador: **http://localhost:8080** (alias / login + misiones).

> **¿Tu usuario no tiene `sudo`/root?** Los escaneos *connect* (`nmap -sT`), `curl`, `dig`,
> `redis-cli` y `nc` funcionan sin privilegios; SYN/UDP/OS (`-sS/-sU/-O`) y `hping3` necesitan
> `sudo`. En tu propia Kali tienes root, así que no hay problema.

> **Opcional** — si un alumno no tiene las herramientas instaladas, hay una estación con
> todo preinstalado: `docker compose --profile tools up -d attacker && docker compose exec attacker bash`.

> Parar: `./stop.sh` (conserva el progreso) · Reset puntuaciones: `make reset` ·
> Borrar todo: `make nuke` · Quitar nombres de /etc/hosts: `sudo ./recon-hosts.sh --undo`

### Requisitos
- Docker Engine + plugin `docker compose` v2 (ya instalados y probados en esta Kali).
- **Permisos de Docker:** el usuario `kali` ya está en el grupo `docker`. Si en otra
  máquina `docker ps` te pide `sudo`, añade el usuario al grupo una vez:
  ```bash
  sudo usermod -aG docker $USER && newgrp docker
  ```
- **Herramientas de recon** (ya presentes en Kali): `nmap`, `hping3`, `dig`, `curl`,
  `nc`, `redis-cli`, `masscan`.

---

## 🗺️ Topología de la red `172.30.0.0/24`

| Host          | IP            | Rol didáctico                                                        |
|---------------|---------------|---------------------------------------------------------------------|
| **scoreboard**| 172.30.0.5    | Plataforma CTF (web → host **:8080**)                               |
| **alpha**     | 172.30.0.21   | Web + SSH reales → discovery, `-sS/-sT`, `-sV`, banner grabbing      |
| **bravo**     | 172.30.0.22   | Detección de versión + **interacción** (redis real → flag)          |
| **charlie**   | 172.30.0.23   | **open / closed / filtered**, firewall, `--reason`, `-sA`           |
| **delta**     | 172.30.0.24   | Ruido y timing: 50 *decoys* + 1 servicio real (aguja en el pajar)   |
| **echo**      | 172.30.0.25   | OS/TTL fingerprinting + el matiz de `-O` en contenedores            |
| **foxtrot**   | 172.30.0.26   | **UDP** (`-sU`) + DNS/NSE (flag en registro TXT)                     |
| **hotel**     | 172.30.0.27   | **hping3** + cabeceras TCP (SYN/ACK/FIN → SYN-ACK / RST / drop)      |

> `172.30.0.10` queda reservada para la estación **opcional** `attacker` (perfil `tools`).

Tras `sudo ./recon-hosts.sh` puedes usar los **nombres** en cualquier comando nativo
(`nmap alpha`, `curl http://bravo/`, `dig @foxtrot flag.recon.lab TXT`). El propio lab
también ofrece DNS interno en **foxtrot** (`172.30.0.26`): `dig @172.30.0.26 alpha.recon.lab`.

---

## 🎮 El juego: misiones, rangos e insignias

El alumno entra con un **callsign** (alias) en el scoreboard y va resolviendo 12 misiones
de dificultad creciente. Cada acierto suma puntos y sube de **rango**:

`Recluta → Explorador → Operador → Analista → Especialista → Maestro Recon`

| ID  | Misión                     | Entrena                              | Pts |
|-----|----------------------------|--------------------------------------|-----|
| M01 | Primer Contacto            | Host discovery (`-sn`)               | 50  |
| M02 | Puertas Abiertas           | Puertos + banner web                 | 100 |
| M03 | Identidades                | Detección de versión (`-sV`)         | 100 |
| M04 | El Tesoro de Redis         | Interacción de servicio (redis)      | 150 |
| M05 | Estados Cuánticos          | open/closed/filtered, puerto oculto  | 150 |
| M06 | Cortafuegos al Desnudo     | Análisis de firewall, `-sA`          | 150 |
| M07 | Aguja en el Pajar          | Decoys, timing, acotar `-p`          | 200 |
| M08 | Huella Digital             | OS/TTL fingerprinting                | 150 |
| M09 | Territorio UDP             | `-sU` + DNS/NSE (TXT)                | 200 |
| M10 | El Arte del Paquete        | **hping3** + cabeceras TCP           | 250 |
| M11 | Operación Sigilo           | Evasión (`-f`, `-D`, `-g 53`)        | 200 |
| M12 | **BOSS — Mapa Total**      | Síntesis (desbloquea al completar)   | 500 |

Insignias: `first-blood`, `udp-diver`, `packet-smith`, `ghost`, `cartographer`.
Los **flags y soluciones** están en `solutions/solucionario.md` (material del instructor).

---

## 📚 Itinerario didáctico recomendado

Lee la teoría y enlázala con las misiones:

1. `docs/00-introduccion.md` · `docs/01-metodologia.md`
2. `docs/02-host-discovery.md` → **M01**
3. `docs/03-tcp-headers.md` (cabeceras TCP/IP, base de todo)
4. `docs/04-tipos-de-escaneo.md` · `docs/05-estados-de-puertos.md` → **M02, M05, M06**
5. `docs/06-version-os-detection.md` → **M03, M04, M08**
6. `docs/07-nse-scripting.md` → **M09**
7. `docs/08-hping3.md` → **M07, M10**
8. `docs/09-evasion-firewall.md` → **M11**
9. `docs/10-misiones-gamificadas.md` (dossier completo) · `docs/cheatsheet.md`

Para impartir: **`docs/instructor-guide.md`** (objetivos, tiempos, rúbrica, tabla de
corrección) y **`solutions/solucionario.md`** (walkthrough con comandos exactos).

---

## 🗂️ Estructura del proyecto

```
recon-lab/
├── docker-compose.yml        # Orquestación: red, IPs fijas, caps, healthchecks
├── start.sh / stop.sh        # Arranque/parada con validación
├── Makefile                  # make up / shell / reset / nuke / check ...
├── LAB-SPEC.md               # Contrato técnico (IPs, puertos, flags, misiones)
├── .env / .dockerignore
├── attacker/                 # Estación ofensiva (nmap, hping3, scapy, dig, redis-cli…)
├── targets/
│   ├── common/portsrv.py     # Simulador TCP/UDP multipuerto compartido
│   ├── alpha … hotel/        # 7 objetivos, cada uno con su Dockerfile y servicios
├── scoreboard/               # CTF Flask + SQLite (app.py, challenges.yml, templates…)
├── docs/                     # Temario completo (00–10) + cheatsheet + guía instructor
└── solutions/                # Solucionario (CONFIDENCIAL, para el instructor)
```

---

## 🧪 Estado de validación

**Construido, desplegado y probado EN VIVO** sobre esta Kali (Docker 28.5):

- ✅ **9 imágenes construidas**; **8 contenedores** activos y *healthy* por defecto
  (scoreboard + 7 objetivos; la estación `attacker` es opcional).
- ✅ **Validación nativa de las 12 misiones — 17/17 PASS** desde el host (sin contenedor
  atacante): host discovery, web/robots/cabecera, `-sV` (nginx/redis), redis `GET flag`,
  estados open/closed/**filtered**, aguja 9042 entre 50 decoys, **TTL=128**, DNS TXT, banners.
- ✅ **Scoreboard en vivo — 19/19 PASS** vía HTTP: login + envío de los 12 flags, desbloqueo
  del boss M12, rango *Maestro Recon* (2200 pts), insignias y leaderboard.
- ✅ **Técnicas raw (= `sudo`) — OK**: `hping3` (flags `SA`/`RA`/100% loss), `-sS`, `-sU`
  (53/123/161), y `-O` mostrando el *caveat* del kernel del host con TTL=128 como pista real.
- ✅ `nginx -t` y `dnsmasq --test` OK · flags coherentes objetivos ↔ `challenges.yml` ↔ `LAB-SPEC`.

> Comprobación rápida tras `./start.sh` (nativo, sin contenedores):
> ```bash
> nmap -sn 172.30.0.0/24                         # M01: descubre los hosts
> curl -s http://172.30.0.21/robots.txt          # flag M02
> sudo nmap -sT -p443 --reason 172.30.0.23        # M06: 443 filtered
> ping -c1 172.30.0.25 | grep -o 'ttl=[0-9]*'     # M08: ttl=128
> ```

---

## 🔧 Solución de problemas

- **`docker compose` pide sudo / "permission denied":** añade tu usuario al grupo `docker`
  (ver Requisitos) o usa `sudo`.
- **`-O` no detecta el SO de los contenedores:** es esperado. En Docker **todos los
  contenedores comparten el kernel del host**, así que `-O` fingerprintea ese kernel. Por
  eso M08 se basa en **inferencia por TTL** (echo fuerza TTL=128 → Windows). Lección, no bug.
- **Algún puerto `filtered` aparece `closed` (o TTL≠128):** significa que las reglas
  iptables del objetivo no se aplicaron. Los entrypoints de charlie/echo/hotel **detectan
  automáticamente** el backend que funciona (`iptables-nft` en kernels modernos; el `legacy`
  falla si no está cargado `ip_tables`). Revisa los logs: `docker compose logs charlie` debe
  mostrar `backend iptables operativo: iptables-nft` y los `DROP`/`TTL` aplicados. Requiere
  `cap_add: NET_ADMIN` (ya está en el compose).
- **`-sU` tarda muchísimo:** es la naturaleza del escaneo UDP (sin respuesta ⇒ reintentos).
  Acota con `-p` y usa `--max-retries 1` para las prácticas.
- **Reiniciar el juego:** `make reset` (borra puntuaciones, conserva imágenes).

---

*Operación Red Recon · laboratorio educativo de reconocimiento de redes · v1.0*
