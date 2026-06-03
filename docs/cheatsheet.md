# Cheatsheet — Operación Red Recon

> **Chuleta de bolsillo (lista para imprimir).** Comandos reales ejecutables
> **NATIVAMENTE desde tu Kali** contra los objetivos del lab (172.30.0.21–.27).
> Tras `sudo ./recon-hosts.sh` puedes usar nombres (`alpha`, `charlie`…) en vez de IPs.
> Los escaneos SYN/UDP/OS y `hping3` van con `sudo`. Recon solo contra tus objetivos.

---

## Tabla de objetivos

| Host        | IP            | Puertos / pistas clave                              | Misiones   |
|-------------|---------------|----------------------------------------------------|------------|
| scoreboard  | 172.30.0.5    | Web CTF (host: <http://localhost:8080>)            | (entregas) |
| alpha       | 172.30.0.21   | 22 ssh · 80 nginx (robots.txt, `X-Recon-Flag`) · 8080 | M02, M03 |
| bravo       | 172.30.0.22   | 6379 redis (sin auth) · 3306 mysql · 5432 postgres | M04        |
| charlie     | 172.30.0.23   | 22 open · 80 closed · 443 filtered · 31337 open*   | M05, M06   |
| delta       | 172.30.0.24   | 9000–9049 = 50 decoys · 9042 = la aguja            | M07        |
| echo        | 172.30.0.25   | 135/139/445 (Windows-like) · TTL forzado a 128     | M08        |
| foxtrot     | 172.30.0.26   | 53 udp+tcp (DNS `recon.lab`) · 123 ntp · 161 snmp  | M09        |
| hotel       | 172.30.0.27   | 22 SYN/ACK · 80 RST · 443 silencio · 7777 open*    | M10, M11   |

`*` = puerto abierto pero "escondido"; lo hallas con escaneo de todo el rango / hping3.

---

## Preparar y orientarse (nativo)

```bash
./start.sh                             # levanta objetivos + scoreboard
sudo ./recon-hosts.sh                  # (una vez) nombres alpha..hotel en /etc/hosts
ip route | grep 172.30                 # tu host enruta al lab (br-...)
ping -c1 172.30.0.21                   # ¿llega alpha?  (o: ping -c1 alpha)
```

---

## nmap — descubrimiento de hosts

```bash
nmap -sn 172.30.0.0/24                 # ping sweep: solo "¿quién está vivo?" (sin puertos)
nmap -sn -n 172.30.0.21-27             # rango de objetivos, sin resolución DNS (-n más rápido)
nmap -sL 172.30.0.0/24                 # solo lista direcciones, sin enviar paquetes
```
*Cuenta las líneas `Host is up`. En red local nmap usa ARP: muy fiable.*

---

## nmap — tipos de escaneo de puertos

```bash
nmap -sS <IP>                          # SYN scan (sigiloso, por defecto con privilegios)
nmap -sT <IP>                          # Connect scan (handshake completo; sin privilegios)
nmap -sU <IP>                          # UDP scan (lento; estados open|filtered)
nmap -sA <IP>                          # ACK scan (mapea reglas de firewall: unfiltered/filtered)
```

### Selección de puertos y velocidad

```bash
nmap -p80,443 <IP>                     # puertos concretos
nmap -p1-1000 <IP>                     # rango
nmap -p- <IP>                          # TODOS los puertos (1-65535) — clave en M05/M07
nmap -F <IP>                           # rápido: top-100 puertos
nmap --top-ports 20 <IP>              # los N más comunes
nmap -T4 <IP>                          # timing más agresivo (lab aislado: seguro)
nmap -v -p- <IP>                       # verboso (ver progreso en escaneos largos)
```

### Estados de puerto que reporta nmap

| Estado            | Significado                                  | Qué llegó         |
|-------------------|----------------------------------------------|-------------------|
| `open`            | Servicio escuchando                          | SYN/ACK           |
| `closed`          | Nadie escucha, host responde                 | RST               |
| `filtered`        | Firewall traga el paquete (DROP)             | nada / ICMP unreach |
| `open\|filtered`  | No se distingue (típico de UDP sin respuesta)| nada              |

---

## nmap — versión, scripts y SO

```bash
nmap -sV <IP>                          # detección de versión de servicio
nmap -sV -p80 172.30.0.21              # versión solo del 80 (M03)
nmap -sV -p9000-9049 172.30.0.24       # banners de un rango (aísla la aguja, M07)
nmap -O <IP>                           # detección de SO (poco fiable en contenedores)
nmap -A <IP>                           # agresivo: -sV + -O + scripts + traceroute
nmap --reason <IP>                     # explica POR QUÉ cada estado (qué paquete llegó)
nmap -sV --version-intensity 9 <IP>    # sondeo de versión más insistente
```

### NSE (Nmap Scripting Engine)

```bash
nmap --script default <IP>             # scripts seguros por defecto (= -sC)
nmap -sU -p53 --script "dns-*" 172.30.0.26   # scripts de DNS sobre UDP/53 (M09)
nmap --script banner -p7777 172.30.0.27      # captura el banner de un puerto
nmap --script-help dns-nsid            # ayuda de un script concreto
ls /usr/share/nmap/scripts/ | grep dns # listar scripts disponibles
```

### Evasión (M11) — uso responsable, solo en el lab

```bash
nmap --source-port 53 -p443 172.30.0.23   # fija puerto de ORIGEN "mágico" (DNS)
nmap -g 53 -p443 172.30.0.23              # forma corta de --source-port
nmap -f <IP>                              # fragmenta los paquetes de sonda
nmap -D RND:5 <IP>                        # decoys (ofusca el origen real)
```

---

## hping3 — paquetes a mano (M10)

```bash
hping3 -S -p 7777 172.30.0.27 -c 3     # SYN scan manual: SA=abierto, R=cerrado, nada=filtrado
hping3 -A -p 80  172.30.0.27 -c 3      # ACK probe (sondeo de firewall)
hping3 -F -p 80  172.30.0.27 -c 3      # FIN scan
hping3 -1 172.30.0.25 -c 3             # modo ICMP (ping): lee el TTL de respuesta (M08)
hping3 -S -p 80 --tcp-timestamp 172.30.0.27 -c 2   # opciones TCP
hping3 -S -p ++22 172.30.0.27 -c 5     # incrementa el puerto destino en cada paquete
```
*Lee `flags=SA` (SYN/ACK → abierto), `flags=R` (RST → cerrado), `ttl=` (huella de SO).*

---

## DNS — dig (M09)

```bash
dig @172.30.0.26 flag.recon.lab TXT    # registro TXT (¡aquí vive el flag!)
dig @172.30.0.26 recon.lab ANY         # todo lo que conteste la zona
dig @172.30.0.26 recon.lab AXFR        # intento de transferencia de zona
dig @172.30.0.26 -p 53 +short flag.recon.lab TXT   # salida limpia
nslookup -type=TXT flag.recon.lab 172.30.0.26      # alternativa
```

---

## Interacción con servicios — nc / ncat (banners)

```bash
nc 172.30.0.23 31337                 # conecta y lee el banner (M05)
nc -v 172.30.0.27 7777               # banner del puerto del flag en hotel (M10)
nc -nv 172.30.0.21 80                  # conexión TCP cruda; escribe la petición a mano
printf 'GET / HTTP/1.0\r\n\r\n' | nc 172.30.0.21 80   # petición HTTP manual
nc -u 172.30.0.26 161                # UDP (banner SNMP-like)
```

---

## Web — curl (M02 / M03)

```bash
curl -I http://172.30.0.21/                 # solo cabeceras (busca X-Recon-Flag)
curl http://172.30.0.21/robots.txt          # ficheros "para robots"
curl -s http://172.30.0.21/ | head          # cuerpo de la página
curl -sv http://172.30.0.21:8080/ 2>&1 | grep -i server   # vhost panel + cabecera Server
```

---

## Redis — redis-cli (M04)

```bash
redis-cli -h 172.30.0.22                # abre sesión interactiva (sin password)
redis-cli -h 172.30.0.22 PING           # ¿responde PONG?
redis-cli -h 172.30.0.22 INFO server    # versión y datos del servidor
redis-cli -h 172.30.0.22 KEYS '*'       # lista TODAS las claves
redis-cli -h 172.30.0.22 GET flag       # extrae el botín de la clave 'flag'
```

---

## Chuleta exprés por misión

| M   | Objetivo            | Comando "de cabecera"                                        |
|-----|---------------------|-------------------------------------------------------------|
| M01 | subred /24          | `nmap -sn 172.30.0.0/24`                                     |
| M02 | alpha web           | `curl -I http://172.30.0.21/` · `curl .../robots.txt`       |
| M03 | alpha versión       | `nmap -sV -p80 172.30.0.21`                                  |
| M04 | bravo redis         | `redis-cli -h 172.30.0.22` → `KEYS *` → `GET flag`          |
| M05 | charlie oculto      | `nmap -p- 172.30.0.23` → `nc 172.30.0.23 31337`           |
| M06 | charlie 443 estado  | `nmap --reason -p80,443 172.30.0.23`                        |
| M07 | delta aguja         | `nmap -sV -p9000-9049 172.30.0.24` (compara banners)        |
| M08 | echo SO/TTL         | `hping3 -1 172.30.0.25 -c3` · `nmap -O 172.30.0.25`         |
| M09 | foxtrot DNS TXT     | `dig @172.30.0.26 flag.recon.lab TXT`                       |
| M10 | hotel hping3        | `hping3 -S -p 7777 172.30.0.27 -c3` → `nc 172.30.0.27 7777` |
| M11 | evasión             | `nmap -g 53 -p443 172.30.0.23` / `nmap -f ...`              |
| M12 | BOSS                | resuelve M02/04/05/07/08/09/10 → reenvía el flag maestro     |

> **Entrega en el scoreboard:** <http://localhost:8080> — flags `RECON{...}` o respuestas
> cortas (número/palabra). `make reset` borra el progreso (uso del instructor).
