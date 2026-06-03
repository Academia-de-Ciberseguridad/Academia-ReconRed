# 05 · Estados de puerto — open, closed, filtered y los estados "cuánticos"

> **Operación Red Recon** · Módulo de escaneo y estados (parte B)
> **Nativo:** ejecutas desde tu Kali contra 172.30.0.21–.27 (SYN/UDP/OS y `hping3` con `sudo`).
> Objetivo estrella de este documento: **charlie** (`172.30.0.23`).
> Misiones conectadas: **M05** (estados cuánticos) y **M06** (cortafuegos al desnudo).

---

## Briefing

Un escaneo no devuelve "abierto / cerrado" y ya está. Nmap maneja **seis estados**,
y la diferencia entre ellos **no es una opinión**: cada estado corresponde a una
**respuesta de red concreta** (o a su ausencia). Entender qué paquete provoca cada
veredicto es la diferencia entre **leer** un escaneo y **adivinar**.

En este documento vas a hacer que **charlie** te lo demuestre, puerto a puerto:

| Puerto charlie | Estado esperado | Quién lo produce |
|---|---|---|
| `22/tcp` | **open** | portsrv escuchando → SYN/ACK |
| `80/tcp` | **closed** | nadie escucha, sin regla → el kernel responde **RST** |
| `443/tcp` | **filtered** | `iptables ... -j DROP` → **silencio** |
| `8000/tcp` | **filtered** | DROP (ruido para practicar) |
| `31337/tcp` | **open** (¡oculto!) | portsrv → banner con el **flag de M05** |

---

## Los seis estados de Nmap

| Estado | Significado | Disparador de red |
|---|---|---|
| **open** | Hay un servicio aceptando conexiones | Respuesta **SYN/ACK** al SYN |
| **closed** | El host responde, pero nadie escucha ese puerto | Respuesta **RST** |
| **filtered** | Algo bloquea el paquete; Nmap no recibe respuesta | **Silencio** (DROP) o ICMP unreachable |
| **open\|filtered** | No se puede distinguir open de filtered | Silencio en técnicas que no provocan RST en open (UDP, Null/FIN/Xmas) |
| **closed\|filtered** | No se puede distinguir closed de filtered | Solo aparece en *idle scan* (`-sI`) |
| **unfiltered** | El puerto es alcanzable, pero no se sabe si open/closed | Respuesta **RST** a un **ACK scan** (`-sA`) |

Los tres primeros son el pan de cada día. Los tres con barra (`|`) son los **estados
"cuánticos"**: Nmap te dice honestamente "podría ser una cosa o la otra, no tengo
información suficiente para colapsar la duda". De ahí el nombre de la misión **M05**.

---

## Cómo distingue Nmap cada estado (el porqué físico)

Todo se reduce a **qué llega de vuelta** tras enviar un SYN (en un SYN/connect scan):

```
        attacker  ──SYN──▶  puerto
                                │
   ┌─────────────┬─────────────┴──────────────┐
   ▼             ▼                             ▼
 SYN/ACK         RST                       (nada)
   │              │                            │
 OPEN          CLOSED                      FILTERED
(hay servicio) (host vivo,            (un firewall se
               nadie escucha)          comió el paquete)
```

- **open** → el servicio en LISTEN hace que el kernel devuelva **SYN/ACK**. El
  three-way handshake *podría* completarse. Hay alguien al otro lado.
- **closed** → no hay proceso escuchando **y no hay regla de firewall**. El kernel,
  educadamente, responde **RST** ("aquí no hay nadie, no insistas"). Clave: **el host
  está vivo y responde**; simplemente ese puerto no tiene servicio.
- **filtered** → un firewall **descarta** (DROP) el paquete. No vuelve nada. Nmap
  reintenta, agota los timeouts y concluye **filtered**. **No sabe** si detrás hay un
  servicio o no: el firewall le tapa la vista.

> **La trampa mental que debes evitar:** `closed` **NO** es "más seguro" que `open`.
> Un puerto `closed` te confirma que **el host está vivo** y te da información. Un
> puerto `filtered` es el que oculta cosas: ahí puede haber un servicio escondido
> (¡como el `31337` de charlie!).

---

## Tus dos linternas: `--reason` y `-v`

Por defecto Nmap te da el **veredicto** pero no la **prueba**. Estas dos opciones te
muestran el razonamiento:

### `--reason` — el "por qué" de cada estado

Añade una columna con la **respuesta de red exacta** que llevó a Nmap a ese veredicto:

```bash
nmap -sS --reason -p 22,80,443,8000,31337 172.30.0.23
```

Razones que verás y su traducción:

| `REASON` | Significado | Estado asociado |
|---|---|---|
| `syn-ack` | Llegó SYN/ACK | **open** |
| `reset` | Llegó un RST | **closed** (o **unfiltered** en ACK scan) |
| `no-response` | No llegó nada tras los reintentos | **filtered** / **open\|filtered** |
| `host-unreach` / `port-unreach` | Llegó un ICMP de inalcanzable | **filtered** / **closed** (UDP) |

> Sin `--reason`, charlie te dice "443 filtered". **Con** `--reason`, te dice "443
> filtered **porque no-response**": ahora **sabes** que hay un DROP detrás, no un
> simple host caído.

### `-v` (y `-vv`) — verbosidad

Muestra el progreso, hosts a medida que se completan y más detalle del proceso.
Combínalo con `--reason` para máxima visibilidad didáctica:

```bash
nmap -sS -v --reason -p 22,80,443,8000,31337 172.30.0.23
```

---

## Laboratorio práctico — charlie, puerto a puerto

> charlie tiene la capability **NET_ADMIN** y, en su arranque, aplica:
> `iptables -A INPUT -p tcp --dport 443 -j DROP` (y lo mismo para 8000, 3389, 5900).
> El puerto **80 NO se toca**: nadie escucha y no hay regla → **el kernel responde
> RST** → **closed**. Esto es lo que produce, físicamente, cada estado.

### Paso 1 — La foto completa con `--reason`

```bash
nmap -sS --reason -p 22,80,443,8000,3389,5900,31337 172.30.0.23 -oA /labs/charlie-estados
```

Salida esperada (resumida) y **lectura**:

```
PORT      STATE    SERVICE      REASON
22/tcp    open     ssh          syn-ack       ← servicio en LISTEN → SYN/ACK
80/tcp    closed   http         reset         ← host vivo, nadie escucha → RST
443/tcp   filtered https        no-response   ← iptables DROP → silencio
8000/tcp  filtered http-alt     no-response   ← DROP (ruido)
3389/tcp  filtered ms-wbt-server no-response  ← DROP (ruido)
5900/tcp  filtered vnc          no-response   ← DROP (ruido)
31337/tcp open     Elite        syn-ack       ← ¡OPEN escondido entre filtrados!
```

**Por qué cada uno:**

- **22 `open` / `syn-ack`:** portsrv está en LISTEN; el kernel completa con SYN/ACK.
- **80 `closed` / `reset`:** no hay servicio **ni** regla. El host está vivo y, como
  buen ciudadano de la red, devuelve **RST**. Eso confirma que charlie **responde**.
- **443 / 8000 / 3389 / 5900 `filtered` / `no-response`:** el DROP de iptables tira
  el SYN al vacío. Nmap reintenta, no obtiene nada y dictamina **filtered**.
- **31337 `open` / `syn-ack`:** la lección de M05. Está **abierto**, pero
  visualmente "enterrado" entre puertos filtrados altos. Si solo escaneas puertos
  comunes (`-F`), **te lo pierdes**.

### Paso 2 — Confirmar el matiz closed vs filtered

Lanza un escaneo sigiloso y mira cómo cambia la ambigüedad:

```bash
nmap -sN --reason -p 22,80,443 172.30.0.23
```

- `80` sigue **closed** (`reset`): el RST del kernel desambigua.
- `22` ahora es **open|filtered** (`no-response`): un puerto **open** **ignora** un
  paquete sin handshake, así que el Null scan no recibe RST y **no puede** confirmar
  "open" a secas. Estado **cuántico**.
- `443` **open|filtered** también, pero por el **DROP**.

> Compara esta salida con la del `-sS`: el SYN scan **sí** colapsa la duda en `22`
> (porque un open responde SYN/ACK al SYN), mientras que el Null scan la mantiene.
> **La técnica que eliges determina cuánta certeza obtienes.**

---

## M05 · Estados Cuánticos — la puerta oculta

El reto **M05** premia que **no te fíes** de un escaneo rápido. El puerto `31337`
está `open` pero rodeado de `filtered`. La lección: **escanea el rango completo** y
**lee con `--reason`**.

```bash
# 1) No te limites a puertos comunes: barre TODO el espacio TCP
nmap -sS -p- --reason 172.30.0.23 -oA /labs/charlie-allports

# 2) Una vez localizado 31337 como open, "asómate" para leer su banner
#    (el banner contiene el flag de M05 — ver doc 06 para banner grabbing)
nc 172.30.0.23 31337
```

**Qué observas y por qué:**

- `-p-` fuerza el escaneo de los 65535 puertos; sin esto, `31337` pasa desapercibido.
- Al conectar con `nc`, charlie te entrega el banner del servicio "oculto". El flag
  de M05 viaja en ese banner.

> 🔒 **Solucionario aparte:** el flag exacto de M05 **no** se transcribe en esta
> teoría. Lo obtienes tú leyendo el banner de `31337/tcp`. Si necesitas verificarlo,
> consúltalo en el documento solucionario del laboratorio.

🏅 **Badge en juego:** el primer flag que envíes te da `first-blood`.

---

## M06 · Cortafuegos al Desnudo — el ACK scan

**M06** pregunta por el **estado del puerto 443 en charlie**, y la respuesta canónica
es **`filtered`**. Pero la gracia no es soltar la palabra: es **demostrarlo** con la
técnica adecuada.

Un **ACK scan** (`-sA`) está hecho para **mapear el firewall**, no los servicios.
Envía solo el flag **ACK** y razona:

- Llega **RST** → **unfiltered** (no hay regla; el ACK alcanzó la pila TCP).
- **Nada** → **filtered** (un firewall *stateful* descartó el ACK).

```bash
nmap -sA --reason -p 22,80,443,8000 172.30.0.23 -oA /labs/charlie-ack
```

Salida esperada y **lectura**:

```
PORT     STATE       SERVICE   REASON
22/tcp   unfiltered  ssh       reset        ← sin regla → RST → unfiltered
80/tcp   unfiltered  http      reset        ← sin regla → RST → unfiltered
443/tcp  filtered    https     no-response  ← iptables DROP → filtered
8000/tcp filtered    http-alt  no-response  ← iptables DROP → filtered
```

**El matiz que separa al operador del novato:**

- `-sA` **NO** dice si 22 u 80 están open o closed. Dice **`unfiltered`**: "no hay
  firewall bloqueándolos". Para saber si están open/closed necesitas un `-sS`.
- `443` y `8000` salen **`filtered`** porque el DROP traga el ACK. **Eso** es la
  prueba de que hay un cortafuegos, y **eso** es lo que responde M06: el estado de
  443 es **`filtered`**.

> **Combo recomendado:** corre `-sS` (te da open/closed/filtered de servicios) **y**
> `-sA` (te confirma *dónde hay reglas*). Juntos te dan la foto completa del
> cortafuegos de charlie.

---

## Tabla-resumen para grabar a fuego

| Veredicto Nmap | Lo que pasó en la red | ¿Host vivo? | ¿Hay servicio? |
|---|---|---|---|
| **open** | SYN/ACK | Sí | **Sí** |
| **closed** | RST | **Sí** | No |
| **filtered** | Silencio (DROP) / ICMP | No se sabe | **No se sabe** (oculto) |
| **open\|filtered** | Silencio en UDP/Null/FIN/Xmas | No se sabe | Quizá |
| **unfiltered** (solo `-sA`) | RST a un ACK | Sí | No determinado |

---

## Laboratorio guiado (cópialo entero)

```bash
# 1) Estados básicos con prueba (--reason): open/closed/filtered en charlie
nmap -sS --reason -p 22,80,443,8000,3389,5900,31337 172.30.0.23 | tee /labs/charlie-estados.txt

# 2) M05: barre TODO el rango para descubrir el 31337 oculto
nmap -sS -p- --reason 172.30.0.23 | tee /labs/charlie-allports.txt

# 3) Estado cuántico: Null scan deja 22 como open|filtered
nmap -sN --reason -p 22,80,443 172.30.0.23 | tee /labs/charlie-null.txt

# 4) M06: ACK scan revela el firewall (443 = filtered)
nmap -sA --reason -p 22,80,443,8000 172.30.0.23 | tee /labs/charlie-ack.txt
```

**Checklist del operador (✔ antes del doc 06):**

- [ ] Sé qué respuesta de red produce **open** (SYN/ACK), **closed** (RST) y
      **filtered** (silencio/DROP).
- [ ] Entiendo por qué `closed` significa **host vivo** y `filtered` significa
      **vista tapada**.
- [ ] Uso `--reason` para **probar** cada estado, no solo afirmarlo.
- [ ] Sé que `-sA` da **unfiltered/filtered**, no open/closed (M06).
- [ ] He barrido `-p-` para no perderme el **31337** (M05).

---

## Próxima parada

En el **documento 06 · Detección de versión y SO** aprendes a leer banners
(`nc`/`ncat`/`curl`), a usar `-sV` con intensidad y `-O`/`--osscan-guess`, y verás
**el gran matiz de los contenedores**: como comparten kernel con el host, `-O`
fingerprintea el host real, y la inferencia por **TTL** se vuelve tu mejor pista
(echo y la misión M08).

> *Un puerto filtrado no es un puerto seguro: es un puerto que aún no has entendido.* 🔐
