# 00 · Introducción — Operación Red Recon

> **Bienvenido, operador.** Te has alistado en **Operación Red Recon**, un laboratorio
> educativo de reconocimiento de redes donde aprenderás a "ver lo invisible": descubrir
> hosts, mapear puertos, identificar servicios y leer las cabeceras TCP a mano. Todo
> dentro de una red Docker **aislada y controlada**, sin tocar nada real. Tu misión:
> ascender de **Recluta** a **Maestro Recon**.

---

## 1. ¿Qué es este laboratorio?

`Operación Red Recon` es una academia de ciberseguridad gamificada centrada en la
**primera fase de cualquier evaluación de seguridad: el reconocimiento**. Trabajarás
con herramientas estándar de la industria —`nmap`, `hping3`, `scapy`— contra una flota
de 7 objetivos (`alpha` … `hotel`), cada uno diseñado para enseñarte una técnica
concreta: descubrimiento de hosts, estados de puerto, detección de versión y de SO,
escaneo UDP y la artesanía de paquetes TCP.

Cada técnica que dominas se traduce en una **misión** (M01 … M12). Resolver una misión
te da un **flag** (`RECON{...}`) o una **respuesta corta** que entregas en el
**scoreboard** para sumar puntos, subir de rango y desbloquear badges.

### Filosofía pedagógica

- **No memorices comandos: entiende qué pregunta hace cada paquete a la red y cómo
  interpretar la respuesta.** Por eso, en cada documento explicamos *qué se observa* en
  la salida y *por qué* (estados de puerto, TTL, flags TCP, cabeceras…).
- **Aprendes haciendo.** Cada misión tiene un ejercicio guiado; el solucionario solo se
  consulta si te atascas (y el instructor decide cuándo liberarlo).

---

## 2. Mapa de la red

Toda la operación vive en la red Docker `recon_net` (bridge), subred **172.30.0.0/24**,
gateway **172.30.0.1**. **Tu propia Kali es la gateway `.1`**, así que tiene visibilidad
directa de toda la subred: escaneas nativamente, sin contenedores intermedios.

| Host        | IP            | Rol pedagógico                                          | Misiones clave |
|-------------|---------------|--------------------------------------------------------|----------------|
| scoreboard  | 172.30.0.5    | Plataforma CTF (web). Donde entregas flags y respuestas | (todas)        |
| alpha       | 172.30.0.21   | Web + SSH reales. Discovery, `-sT`/`-sS`, `-sV`        | M02, M03       |
| bravo       | 172.30.0.22   | Detección de versión + interacción (redis, MySQL, Postgres) | M04        |
| charlie     | 172.30.0.23   | Estados de puerto: open/closed/filtered, firewall      | M05, M06       |
| delta       | 172.30.0.24   | Ruido / decoys / timing (~50 puertos + 1 real)         | M07            |
| echo        | 172.30.0.25   | Detección de SO/TTL y sus límites en contenedores      | M08            |
| foxtrot     | 172.30.0.26   | Escaneo UDP + NSE/DNS (registro TXT)                   | M09            |
| hotel       | 172.30.0.27   | hping3 + cabeceras TCP (SYN/ACK/FIN, window, TTL)      | M10            |

> **Nota importante.** El `scoreboard` **no es objetivo** de las misiones de mapeo: tu
> trabajo es contra `alpha`…`hotel` (172.30.0.21–.27). Sin embargo, un barrido de
> descubrimiento de hosts (M01) **sí verá** el scoreboard y el gateway (tu propia Kali). El
> conteo exacto de "hosts vivos" tiene un matiz que se explica en
> [02 · Host Discovery](02-host-discovery.md) — y es justo lo que mide la Misión 01.

### Objetivos vivos (172.30.0.21–.27)

```
172.30.0.21  alpha     Web/SSH reales
172.30.0.22  bravo     redis / MySQL / Postgres
172.30.0.23  charlie   open/closed/filtered + firewall
172.30.0.24  delta     50 decoys + 1 real
172.30.0.25  echo      OS/TTL (TTL forzado a 128)
172.30.0.26  foxtrot   UDP + DNS (recon.lab)
172.30.0.27  hotel     hping3 / cabeceras TCP
```

---

## 3. Cómo levantar el laboratorio

Necesitas **Docker** con el plugin `compose`. Desde la raíz del repo
(`/home/kali/recon-lab`):

```bash
# Construir y levantar todo (la primera vez tarda un poco al construir imágenes)
docker compose up -d --build
```

Atajos equivalentes (opcionales):

```bash
./start.sh        # arranque guiado con comprobaciones
make up           # build + up -d
make help         # lista todos los atajos disponibles
```

Comprueba que todo está arriba:

```bash
docker compose ps
```

Deberías ver **8** contenedores `Up`: el `scoreboard` y los **7 objetivos**
(alpha…hotel). La estación `attacker` es **opcional** y NO se levanta por defecto.
Espera ~15 s a que los servicios internos arranquen antes de empezar a escanear.

> **Sugerencia:** si algo no cuadra, valida la configuración con `make check`
> (`docker compose config -q`) o revisa logs con `docker compose logs -f`.

---

## 4. Tu puesto de operaciones: tu propia Kali (NATIVO)

No necesitas ningún contenedor atacante. La red del laboratorio (`172.30.0.0/24`) es
**accesible directamente desde tu Kali**, así que ejecutas `nmap`, `hping3`, `dig`, etc.
**de forma nativa**. Es más cómodo y más realista.

Un único paso recomendado: registra los nombres de los objetivos en tu `/etc/hosts`
para poder usar `alpha`, `bravo`, … en vez de IPs:

```bash
sudo ./recon-hosts.sh        # añade alpha..hotel a /etc/hosts (revertir: --undo)
```

Verifica que llegas a los objetivos:

```bash
ip route | grep 172.30           # tu host enruta a la red del lab (br-...)
ping -c1 172.30.0.21             # ¿llega alpha?  (o: ping -c1 alpha)
```

> **Privilegios:** los escaneos *connect* (`nmap -sT`), `curl`, `dig`, `redis-cli` y `nc`
> funcionan sin root. Los escaneos **SYN/UDP/OS** (`-sS`, `-sU`, `-O`) y **`hping3`** usan
> sockets en crudo: ejecútalos con `sudo`. En tu Kali tienes root, así que sin problema.

> **Alternativa opcional:** si prefieres una consola con todo preinstalado, levanta la
> estación `attacker` (no necesaria): `make tools` y luego `make shell`. Dentro tienes
> los atajos `recon-help` y `recon-targets`.

A partir de aquí, los ejemplos de los documentos usan los **nombres** (`alpha`, `charlie`…);
funcionan nativamente si has ejecutado `recon-hosts.sh`, o sustitúyelos por su IP.

---

## 5. El scoreboard

El **scoreboard** es tu cuartel general: ahí ves las misiones, entregas flags y
respuestas, y sigues tu progreso, rango y badges.

- **URL (desde tu navegador del host):** <http://localhost:8080>
  (internamente es el contenedor `scoreboard` en 172.30.0.5, puerto 8000 → host 8080).
- **Qué entregas:**
  - **Flags** con formato `RECON{...}` (ej. misiones de loot).
  - **Respuestas cortas** (ej. un número de hosts, un estado de puerto, un SO).
- **Puntos y rango** se actualizan al validar cada entrega.

### Tipos de misión

| Tipo     | Qué entregas                          | Ejemplo                          |
|----------|---------------------------------------|----------------------------------|
| `flag`   | Una cadena `RECON{...}` que encuentras| M02, M04, M05, M07, M09, M10, M12|
| `answer` | Una respuesta corta (número/palabra)  | M01, M03, M06, M08, M11          |

> El scoreboard valida `answer` de forma tolerante cuando procede (p. ej. mayúsculas/
> minúsculas, o varias respuestas aceptadas en M01 y M11). Los detalles de cada misión
> están en sus documentos correspondientes.

### Rangos (gamificación)

Tus puntos acumulados determinan tu rango:

| Puntos      | Rango           |
|-------------|-----------------|
| 0–99        | Recluta         |
| 100–299     | Explorador      |
| 300–599     | Operador        |
| 600–999     | Analista        |
| 1000–1499   | Especialista    |
| 1500+       | **Maestro Recon** |

### Badges

`first-blood` (tu primer flag), `udp-diver` (M09), `packet-smith` (M10),
`ghost` (M11 · evasión), `cartographer` (M12), `speedrunner` (5 retos en < 30 min,
opcional según instructor).

> Para reiniciar el progreso (uso del instructor): `make reset`.

---

## 6. Reglas del juego

1. **Solo se ataca a los objetivos del lab** (172.30.0.21–.27). El scoreboard y el
   gateway no son "presas".
2. **Trabaja nativamente desde tu Kali** (con `sudo` para escaneos SYN/UDP/OS y `hping3`).
3. **Entiende antes de copiar.** Cada comando del documento explica qué hace y qué
   esperar; el objetivo es que sepas *leer* la salida.
4. **No se comparten flags fuera del scoreboard.** Encontrar el flag es el ejercicio;
   pegarlo de un compañero no enseña nada.
5. **Documenta tu proceso.** Un buen operador anota qué probó, qué vio y qué concluyó
   (ver metodología en [01 · Metodología](01-metodologia.md)).

---

## 7. Advertencia ética

> **IMPORTANTE.** Este laboratorio es un **entorno aislado y de uso exclusivamente
> educativo**. Varios objetivos usan capacidades elevadas (`NET_ADMIN`) para manipular
> `iptables`/TTL y enseñarte estados de puerto, firewall y huella de SO de forma segura.

- **No expongas esta red a Internet.** Está pensada para vivir en tu máquina, detrás de
  Docker, sin enrutamiento externo.
- Las técnicas que aprendes aquí (escaneo, enumeración, fabricación de paquetes) **solo
  son legales contra sistemas de tu propiedad o con autorización explícita por escrito**.
- Reconocer redes ajenas sin permiso es un delito en la mayoría de jurisdicciones. Lo
  que practicas aquí es una **habilidad profesional defensiva/ofensiva responsable**: el
  marco legal y el alcance autorizado se tratan en [01 · Metodología](01-metodologia.md).

El conocimiento es una herramienta. Úsalo para **proteger**.

---

## 8. Índice de la documentación

### Fundamentos
- [00 · Introducción](00-introduccion.md) — *(este documento)*
- [01 · Metodología profesional de reconocimiento](01-metodologia.md)
- [02 · Descubrimiento de hosts](02-host-discovery.md) — **M01**
- [03 · Anatomía de las cabeceras TCP/IP y el handshake](03-tcp-headers.md)

### Técnicas por objetivo
- [04 · Tipos de escaneo (`-sT`, `-sS`, `-sU`, `-sA`), decoys y timing](04-tipos-de-escaneo.md) — **M02, M07**
- [05 · Estados de puerto y firewalls](05-estados-de-puertos.md) — **M05, M06**
- [06 · Detección de versión y de SO/TTL (`-sV`, `-O`)](06-version-os-detection.md) — **M03, M04, M08**
- [07 · Motor de scripts NSE](07-nse-scripting.md) — **M09**
- [08 · hping3 y artesanía de paquetes](08-hping3.md) — **M10**
- [09 · Evasión de firewalls (responsable)](09-evasion-firewall.md) — **M11**
- [10 · Dossier de misiones gamificadas](10-misiones-gamificadas.md) — **todas**

### Material de apoyo
- [Cheatsheet de comandos](cheatsheet.md)
- [Guía del instructor](instructor-guide.md)
- [Solucionario](../solutions/solucionario.md) — *(uso restringido; contiene flags)*

---

> **Listo, operador.** Levanta el lab (`./start.sh`), registra los nombres
> (`sudo ./recon-hosts.sh`), abre el scoreboard y empieza por la
> [Misión 01 · Primer Contacto](02-host-discovery.md) con `nmap -sn 172.30.0.0/24`.
> La red te espera.
