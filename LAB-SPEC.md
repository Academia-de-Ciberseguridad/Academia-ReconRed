# LAB-SPEC — Contrato técnico de "Operación Red Recon"

> **Este archivo es la ÚNICA fuente de verdad.** Todos los Dockerfiles, configs,
> el scoreboard y la documentación DEBEN respetar exactamente estos nombres, IPs,
> puertos y flags. Si algo no cuadra con este documento, el documento gana.

## 1. Topología de red

- Red Docker: `recon_net` (bridge), subred **172.30.0.0/24**, gateway 172.30.0.1
- Nombre de proyecto compose: `recon-lab`

| Servicio (compose) | Hostname  | IP            | Rol pedagógico                                  | Caps especiales         |
|--------------------|-----------|---------------|-------------------------------------------------|-------------------------|
| `scoreboard`       | scoreboard| 172.30.0.5    | Plataforma CTF (web, puerto 8000→host 8080)     | —                       |
| `attacker`         | attacker  | 172.30.0.10   | Estación del alumno (nmap, hping3, scapy...)    | NET_RAW, NET_ADMIN      |
| `alpha`            | alpha     | 172.30.0.21   | Web + SSH reales. Discovery, -sT/-sS, -sV       | —                       |
| `bravo`            | bravo     | 172.30.0.22   | Detección de versión + interacción (redis)      | —                       |
| `charlie`          | charlie   | 172.30.0.23   | Estados de puerto: open/closed/filtered, FW     | NET_ADMIN               |
| `delta`            | delta     | 172.30.0.24   | Ruido/decoys/timing (~50 puertos + 1 real)      | —                       |
| `echo`             | echo      | 172.30.0.25   | OS/TTL detection + sus límites en contenedores  | NET_ADMIN               |
| `foxtrot`          | foxtrot   | 172.30.0.26   | UDP scanning + NSE/DNS (TXT)                     | —                       |
| `hotel`            | hotel     | 172.30.0.27   | hping3 + cabeceras TCP (SYN/ACK/FIN, win, TTL)  | NET_ADMIN               |

> `attacker` y `scoreboard` NO deben aparecer como "objetivos" en las misiones de
> mapeo, pero el barrido de host discovery (M01) SÍ los verá. Ver M01 para el conteo.

## 2. Imagen base compartida

- Todos los builds usan **contexto = raíz del repo** (`context: .`) y `dockerfile:
  targets/<n>/Dockerfile`, para poder `COPY targets/common/portsrv.py`.
- `targets/common/portsrv.py`: simulador TCP/UDP multipuerto, **solo stdlib**.
  Configurable vía env `PORTSRV_CONFIG=/etc/portsrv.json`. Modos: `banner`, `http`,
  `echo`, y `proto: udp`. Soporta `port_range: [ini,fin]` para abrir muchos puertos.

### Formato de /etc/portsrv.json
```json
{
  "default_close_ms": 1500,
  "ports": [
    {"port": 22, "mode": "banner", "banner": "SSH-2.0-OpenSSH_8.9p1\r\n"},
    {"port": 80, "mode": "http", "http_status": "200 OK",
     "http_headers": {"Server": "nginx/1.24.0", "X-Recon-Flag": "RECON{...}"},
     "http_body": "<html>..</html>"},
    {"port": 161, "proto": "udp", "mode": "banner", "banner": "public\n"},
    {"port_range": [9000, 9049], "mode": "banner", "banner": "decoy-service ready\r\n"}
  ]
}
```

## 3. Mapa de puertos y servicios por objetivo

### alpha (172.30.0.21) — Web/SSH reales
- 22/tcp  → OpenSSH real (banner real para `-sV`)
- 80/tcp  → nginx real. `/` y `/robots.txt`. Header `X-Recon-Flag`.
- 8080/tcp→ nginx vhost "panel" con pista de la versión.
- **Flag web (M02):** `RECON{w3b_r3con_h0st_alph4}` en `/robots.txt` y header `X-Recon-Flag`.

### bravo (172.30.0.22) — Versión + interacción
- 6379/tcp → redis real. Clave `flag` = el flag de M04. Sin password.
- 3306/tcp → banner MySQL simulado (portsrv) para `-sV`.
- 5432/tcp → banner PostgreSQL simulado (portsrv).
- **Flag redis (M04):** `RECON{r3d1s_k3y_l00t3d}` (en `GET flag`).

### charlie (172.30.0.23) — Estados de puerto / firewall (NET_ADMIN)
- 22/tcp   → **open** (banner SSH simulado).
- 80/tcp   → **closed** (iptables REJECT --reject-with tcp-reset).
- 443/tcp  → **filtered** (iptables DROP).
- 8000/tcp → **filtered** (DROP) — ruido.
- 31337/tcp→ **open** pero "escondido" entre filtrados; banner con el flag.
- **Flag oculto (M05):** `RECON{f1lt3r3d_d00r_0p3n3d}` (banner de 31337).

### delta (172.30.0.24) — Ruido/decoys/timing
- 9000–9049/tcp → 50 decoys idénticos (portsrv, banner genérico).
- 9042/tcp     → el ÚNICO real/distinto: banner especial con el flag.
  (9042 está dentro del rango pero su entrada específica gana al rango.)
- **Flag aguja (M07):** `RECON{n33dl3_1n_th3_st4ck}`.

### echo (172.30.0.25) — OS/TTL (NET_ADMIN)
- 135/tcp, 139/tcp, 445/tcp → banners "Windows-like" (portsrv) para sugerir SO.
- TTL de salida forzado a **128** vía `iptables -t mangle ... TTL --ttl-set 128`.
- **Flag TTL (M08):** `RECON{ttl_128_w1nd0ws_v1b3s}` en banner de 445.
- Respuesta de misión: SO sugerido = **Windows**.

### foxtrot (172.30.0.26) — UDP + DNS/NSE
- 53/udp+tcp → dnsmasq real. Zona `recon.lab`. Registro TXT con el flag.
- 123/udp    → banner NTP-like (portsrv udp).
- 161/udp    → banner SNMP-like (portsrv udp).
- **Flag DNS (M09):** `RECON{udp_dns_txt_3num3r4t3d}` en TXT de `flag.recon.lab`.

### hotel (172.30.0.27) — hping3 / cabeceras TCP (NET_ADMIN)
- 22/tcp   → **open** (banner) → responde SYN/ACK.
- 80/tcp   → **closed** (REJECT tcp-reset) → responde RST.
- 443/tcp  → **filtered** (DROP) → sin respuesta.
- 7777/tcp → **open**, banner con el flag (recompensa tras enumerar con hping3).
- **Flag hping (M10):** `RECON{h4ndcr4ft3d_p4ck3ts}`.

## 4. Catálogo COMPLETO de flags/answers (canónico para challenges.yml)

| ID  | Misión / título            | Tipo     | Valor canónico                          | Pts |
|-----|----------------------------|----------|-----------------------------------------|-----|
| M01 | Primer Contacto            | answer   | `8` (hosts vivos: scoreboard+8 objetivos sin contar al propio attacker → ver nota) | 50 |
| M02 | Puertas Abiertas           | flag     | `RECON{w3b_r3con_h0st_alph4}`           | 100 |
| M03 | Identidades (versión)      | answer   | `nginx` (servicio en alpha:80; case-insensitive) | 100 |
| M04 | El Tesoro de Redis         | flag     | `RECON{r3d1s_k3y_l00t3d}`               | 150 |
| M05 | Estados Cuánticos          | flag     | `RECON{f1lt3r3d_d00r_0p3n3d}`           | 150 |
| M06 | Cortafuegos al Desnudo     | answer   | `filtered` (estado de 443 en charlie)   | 150 |
| M07 | Aguja en el Pajar          | flag     | `RECON{n33dl3_1n_th3_st4ck}`            | 200 |
| M08 | Huella Digital (OS/TTL)    | answer   | `windows` (case-insensitive)            | 150 |
| M09 | Territorio UDP             | flag     | `RECON{udp_dns_txt_3num3r4t3d}`         | 200 |
| M10 | El Arte del Paquete (hping)| flag     | `RECON{h4ndcr4ft3d_p4ck3ts}`            | 250 |
| M11 | Operación Sigilo (evasión) | answer   | `21` (puerto que delata la pista; ver doc 09 / instructor) | 200 |
| M12 | BOSS — Mapa Total          | flag     | `RECON{m4st3r_r3c0n_c0mpl3t3}`          | 500 |

> **Nota M01 (conteo de hosts vivos con `-sn`):** desde `attacker`, un
> `nmap -sn 172.30.0.0/24` ve: gateway (.1) NO cuenta como objetivo del lab,
> scoreboard(.5) + alpha..hotel(.21–.27 = 7) + el propio attacker no se cuenta a
> sí mismo. Para evitar ambigüedad, la respuesta válida del scoreboard acepta
> **8** (scoreboard + 7 objetivos) y también **9** (si incluye gateway). El
> challenges.yml define `accept: ["8","9"]`. La doc 02 explica el matiz (gateway,
> direcciones de red/broadcast) como lección.

> **M11 (evasión):** la pista premia haber usado `--source-port 53`/`-g 53` o
> fragmentación `-f` contra charlie/hotel para atravesar reglas. La respuesta
> canónica es el nº de puerto fuente "mágico" clásico de evasión = **53** (DNS).
> AJUSTE: usar `accept: ["53","21","20"]` y explicarlo en doc 09. (El instructor
> puede endurecerlo.) → challenges.yml manda; doc 09 debe coincidir.

> **M12 (boss):** el flag maestro se "entrega" como recompensa final. Para que sea
> demostrable, hotel/alpha NO lo exponen; el scoreboard lo concede al completar
> M02..M10 (lógica de desbloqueo) y muestra el flag maestro para que el alumno lo
> reenvíe (ritual de cierre) — o el instructor lo entrega. challenges.yml define
> M12 con `requires: [M02,M04,M05,M07,M08,M09,M10]`.

## 5. Rangos / gamificación

Puntos acumulados → rango:
- 0–99 **Recluta**
- 100–299 **Explorador**
- 300–599 **Operador**
- 600–999 **Analista**
- 1000–1499 **Especialista**
- 1500+ **Maestro Recon**

Badges: `first-blood` (primer flag de cualquier reto), `udp-diver` (M09),
`packet-smith` (M10), `ghost` (M11), `cartographer` (M12), `speedrunner`
(completar 5 retos en < 30 min — opcional/instructor).

## 6. Convenciones

- Todos los flags con formato `RECON{...}`.
- Banners de portsrv deben imitar servicios reales lo suficiente para que
  `nmap -sV` los clasifique de forma didáctica (no perfecta).
- Cada `entrypoint.sh` arranca servicios en segundo plano y termina con un
  proceso en primer plano que mantiene vivo el contenedor (`portsrv.py` o `wait`).
- Healthchecks opcionales pero recomendados en compose.
