# 06 · Detección de versión y de sistema operativo (`-sV`, `-O`, banners y TTL)

> **Operación Red Recon** · Módulo de escaneo y estados (parte B)
> **Nativo:** ejecutas desde tu Kali contra 172.30.0.21–.27 (SYN/UDP/OS y `hping3` con `sudo`).
> Objetivos de práctica: **alpha** (`172.30.0.21`), **bravo** (`172.30.0.22`)
> y **echo** (`172.30.0.25`).
> Misiones conectadas: **M03** (identidades), **M04** (redis) y **M08** (OS/TTL).

---

## Briefing

Saber que un puerto está **open** es el principio. La pregunta del operador es:
**¿qué corre exactamente ahí detrás, y qué versión?** Esa respuesta es la que abre
puertas: una versión concreta = vulnerabilidades concretas.

En este documento aprendes tres niveles de "interrogatorio":

1. **`-sV`** — Nmap interroga al servicio y deduce **producto y versión**.
2. **Banner grabbing manual** — tú mismo lees lo que el servicio "dice" con
   `nc`/`ncat`/`curl`. Control fino y, a menudo, **el flag**.
3. **`-O`** — Nmap intenta deducir el **sistema operativo**… con una limitación
   enorme en contenedores que aquí entenderás a fondo (y que convierte al **TTL** en
   tu mejor pista, misión **M08**).

---

## 1) `-sV` — Detección de versión de servicio

`-sV` no se conforma con "open": **abre la conexión, manda sondas y compara** las
respuestas contra la base de datos `nmap-service-probes`. El resultado es una columna
**VERSION** con producto, versión y a veces detalles extra.

```bash
# Versión de los servicios reales de alpha
nmap -sV --reason -p 22,80,8080 172.30.0.21
```

**Qué observas y por qué en alpha:**

- `22/tcp open ssh OpenSSH ...` → el **banner real** de OpenSSH delata producto y
  versión exactos. SSH se identifica en cuanto conectas (envía su banner el primero).
- `80/tcp open http nginx ...` → nginx **real** se identifica por la cabecera
  `Server:` y por cómo responde a la sonda HTTP.
- **M03** pregunta por el **servicio en `alpha:80`**; la respuesta canónica es
  **`nginx`** (case-insensitive). `-sV` te lo entrega en bandeja.

### `--version-intensity` — cuánto insistir

`-sV` envía sondas con una **intensidad** de **0 a 9**:

- `--version-intensity 0` → solo las sondas más probables (rápido, menos preciso).
- `--version-intensity 9` → **todas** las sondas (lento, máxima precisión).
- Atajos: **`--version-light`** = intensidad **2**; **`--version-all`** = intensidad
  **9**.

```bash
# Ligero y rápido (intensidad 2)
nmap -sV --version-light -p 22,80 172.30.0.21

# A fondo (intensidad 9): útil con servicios "raros" o banners parciales
nmap -sV --version-all -p 3306,5432 172.30.0.22
```

**Por qué importa la intensidad en bravo:**

- bravo simula MySQL (3306) y PostgreSQL (5432) con **banners** servidos por
  `portsrv`. No son servidores reales completos, así que `-sV` puede necesitar **más
  intensidad** para clasificarlos de forma didáctica.
- `3306/tcp` → el banner empieza con la versión `5.7.40-recon`, lo que orienta a
  Nmap hacia **mysql 5.7.x**.
- `5432/tcp` → responde con un mensaje de error tipo PostgreSQL (`FATAL ...
  PostgreSQL 14.7`), suficiente para una clasificación orientativa.

> **Recuerda:** los banners del lab **imitan** servicios reales "lo justo" para que
> `-sV` los clasifique de forma educativa, **no perfecta**. Si Nmap duda, te mostrará
> una huella entre interrogantes y un enlace para reportarla: eso es normal aquí.

---

## 2) Banner grabbing manual — tú, cara a cara con el servicio

`-sV` automatiza, pero el operador debe saber **leer un banner a mano**. Muchas veces
es más rápido, más sigiloso y, en este lab, **es donde están los flags**.

### Con `nc` / `ncat` (servicios de texto)

```bash
# SSH se presenta solo: conecta y lee su banner
nc 172.30.0.21 22

# bravo:6379 es redis REAL. Habla su protocolo y saquea la clave 'flag' (M04)
nc 172.30.0.22 6379
# escribe:  GET flag     y pulsa Enter  -> te devuelve el valor (el flag de M04)
```

**Qué observas y por qué:**

- En `22` ves la línea `SSH-2.0-OpenSSH_...`: SSH **siempre** envía su banner al
  conectar, por eso es trivial de identificar.
- En `6379`, redis **no** tiene un banner de bienvenida: hay que **hablarle**. El
  comando `GET flag` recupera el valor de la clave `flag`. Ese valor es el flag de
  **M04** (no se transcribe aquí; lo obtienes tú).

> Alternativa con redis-cli si lo tienes en attacker:
> ```bash
> redis-cli -h 172.30.0.22 GET flag
> ```

### Con `curl` (servicios HTTP)

Para web, `curl` es más cómodo que `nc`: te enseña cabeceras y cuerpo por separado.

```bash
# Solo cabeceras (-I): mira 'Server:' y la cabecera personalizada del lab
curl -sI http://172.30.0.21/

# Cabeceras + cuerpo (-i): útil para ver el HTML
curl -si http://172.30.0.21/robots.txt
```

**Qué observas y por qué en alpha:**

- La cabecera `Server: nginx/...` confirma **M03** (servicio = `nginx`) **sin** lanzar
  `-sV`.
- alpha añade una cabecera personalizada **`X-Recon-Flag`** y expone `/robots.txt`:
  ahí vive el flag de **M02**. (No se transcribe en esta teoría; léelo tú.)

> **Truco:** `curl -sI` (mayúscula `I`) hace una petición `HEAD` → solo cabeceras,
> rapidísimo. `-i` (minúscula) muestra cabeceras **y** cuerpo.

---

## 3) `-O` — Detección de sistema operativo (y el GRAN matiz de los contenedores)

`-O` intenta adivinar el **SO** del objetivo enviando una batería de sondas y
analizando **detalles finos de la pila TCP/IP**: TTL inicial, tamaño de ventana,
opciones TCP, comportamiento ante paquetes raros… y comparándolos con la base
`nmap-os-db`.

```bash
# Detección de SO sobre echo (requiere raw sockets; attacker ya tiene NET_RAW)
nmap -O 172.30.0.25
```

### ⚠️ El matiz que TIENES que entender: kernel compartido

Aquí está la lección más importante del documento. **Los contenedores Docker
comparten el kernel del host.** No virtualizan un sistema operativo completo: usan
**la misma pila TCP/IP del host anfitrión**.

Consecuencia directa:

> Cuando lanzas `nmap -O` contra **echo** (o cualquier objetivo del lab), **no estás
> fingerprinteando el "SO de echo"**: estás fingerprinteando **el kernel Linux del
> host** que ejecuta Docker. Todos los contenedores te darán, en esencia, **la misma
> huella de SO**, porque comparten kernel.

Por eso, en este laboratorio, **`-O` por sí solo es engañoso**: dirá "Linux" para
todo, incluso para un objetivo que *pretende* ser Windows. La detección de SO clásica
asume **una máquina = una pila TCP/IP**, y los contenedores rompen esa premisa.

### `--osscan-guess` — cuando Nmap no está seguro

Si Nmap no encuentra una coincidencia exacta, `--osscan-guess` (o `--fuzzy`) le pide
que **arriesgue** las conjeturas más cercanas, con un porcentaje de confianza:

```bash
nmap -O --osscan-guess 172.30.0.25
```

Útil cuando la huella es parcial, pero **ojo**: en el lab seguirá sesgado hacia el
kernel del host. Tómalo como una pista, no como un veredicto.

---

## 4) Inferencia por **TTL** — tu mejor pista cuando `-O` falla

Si `-O` está cegado por el kernel compartido, ¿cómo deduces el "SO" que un objetivo
*quiere aparentar*? Con el **TTL** (Time To Live) de los paquetes que recibes.

Cada SO **inicializa el TTL** de sus paquetes salientes con un valor característico:

| TTL inicial típico | Sistema sugerido |
|---|---|
| **64** | **Linux** / Unix / macOS |
| **128** | **Windows** |
| **255** | Equipos de **red** (routers, switches Cisco, algunos *appliances*) |

Como el TTL **disminuye en 1 por cada salto (router)**, el valor que **tú recibes**
es ligeramente menor que el inicial. En el lab, attacker y los objetivos están en la
**misma red Docker** (`recon_net`, sin saltos intermedios), así que el TTL que ves es
prácticamente el inicial.

### Cómo leer el TTL

```bash
# Un simple ping muestra el TTL de la respuesta
ping -c 1 172.30.0.25
#   ... 64 bytes from 172.30.0.25: icmp_seq=1 ttl=128 ...   <- ¡128 = Windows!
```

También lo ves con hping3 (campo `ttl=` en cada respuesta) o capturando con tcpdump.

---

## M08 · Huella Digital — echo finge ser Windows

**echo** (`172.30.0.25`) es la lección viva de este documento. Hace **dos cosas** para
**aparentar Windows**, aunque por dentro sea Linux:

1. **Banners "Windows-like"** en puertos típicos de Windows:
   - `135/tcp` → msrpc (Microsoft RPC Endpoint Mapper)
   - `139/tcp` → netbios-ssn (NetBIOS Session Service)
   - `445/tcp` → microsoft-ds (SMB)
2. **TTL de salida forzado a 128** mediante una regla iptables en la tabla *mangle*
   (`iptables -t mangle -A OUTPUT -j TTL --ttl-set 128`). Por eso echo tiene la
   capability **NET_ADMIN**.

El experimento que lo demuestra todo:

```bash
# 1) -O dice "Linux" (está viendo el kernel del HOST, no el de echo)
nmap -O 172.30.0.25 | tee /labs/echo-O.txt

# 2) Pero los puertos abiertos GRITAN "Windows"
nmap -sV -p 135,139,445 172.30.0.25 | tee /labs/echo-sV.txt

# 3) Y el TTL lo confirma: 128 = Windows
ping -c 1 172.30.0.25
```

**Qué observas y por qué:**

- `nmap -O` reporta **Linux** (o una huella confusa): está leyendo la pila del host
  compartido. **No te fíes de él aquí.**
- `-sV` sobre 135/139/445 devuelve servicios típicos de **Windows** → **pista 1**.
- `ping` muestra **`ttl=128`** → **pista 2**, coherente con Windows.

Cruzando **banners (servicios Windows) + TTL (128)**, la inferencia razonada es
**Windows**, que es exactamente la respuesta de **M08** (`windows`, case-insensitive).
El flag-banner de M08 vive en el puerto **445**; léelo con:

```bash
nc 172.30.0.25 445
```

> 🧠 **La moraleja de M08:** la detección automática de SO (`-O`) **no es un oráculo**.
> Un operador competente **triangula**: combina banners de servicios, TTL y contexto
> en lugar de creerse una sola herramienta. En contenedores, esa triangulación **no
> es opcional**: es la única forma fiable.

> 🔒 **Solucionario aparte:** el flag exacto de M08 **no** se transcribe aquí. Lo lees
> tú en el banner de `445/tcp`. Verifícalo, si hace falta, en el documento
> solucionario.

---

## Tabla-resumen para grabar a fuego

| Quieres saber… | Herramienta | Pista clave |
|---|---|---|
| Producto/versión de un servicio | `nmap -sV` | columna VERSION |
| Cuánto insistir en la versión | `--version-intensity 0..9` | `--version-light` / `--version-all` |
| Banner de un servicio de texto | `nc` / `ncat` | lo que el servicio "dice" |
| Cabeceras / cuerpo HTTP | `curl -sI` / `curl -si` | `Server:`, cabeceras custom |
| SO real de la máquina | `nmap -O` | **¡cegado por el kernel compartido en contenedores!** |
| SO que un objetivo *aparenta* | **TTL** (`ping`, hping3) | 64=Linux · 128=Windows · 255=red |

---

## Laboratorio guiado (cópialo entero)

```bash
# 1) Versión de servicios REALES en alpha (M03: servicio en :80 = nginx)
nmap -sV --reason -p 22,80,8080 172.30.0.21 | tee /labs/alpha-sV.txt
curl -sI http://172.30.0.21/                 | tee /labs/alpha-headers.txt

# 2) Banners simulados en bravo (intensidad alta para clasificarlos)
nmap -sV --version-all -p 3306,5432 172.30.0.22 | tee /labs/bravo-sV.txt
#    redis REAL: saquea la clave 'flag' (M04)
redis-cli -h 172.30.0.22 GET flag    # o:  nc 172.30.0.22 6379  -> GET flag

# 3) echo y M08: -O miente, los banners + TTL dicen la verdad (Windows)
nmap -O 172.30.0.25                  | tee /labs/echo-O.txt
nmap -sV -p 135,139,445 172.30.0.25  | tee /labs/echo-sV.txt
ping -c 1 172.30.0.25                | tee /labs/echo-ttl.txt
```

**Checklist del operador (✔ módulo completado):**

- [ ] Sé usar `-sV` y graduar su **intensidad** (`0..9`, `--version-light/-all`).
- [ ] Sé hacer **banner grabbing** con `nc`/`ncat` y `curl`.
- [ ] Entiendo por qué `-O` **se equivoca en contenedores** (kernel compartido).
- [ ] Sé inferir el "SO aparente" por **TTL** (64 / 128 / 255).
- [ ] He triangulado **banners + TTL** para resolver **M08** (= windows).

---

## Has cerrado el módulo de escaneo y estados (parte B)

Ya distingues **técnicas** (doc 04), **estados** (doc 05) y **versiones/SO** (doc 06).
Con esto tienes el arsenal para mapear cualquiera de los objetivos del lab y empezar a
acumular puntos rumbo al rango **Maestro Recon**.

> *Las herramientas opinan; el operador concluye. Triangula siempre.* 🛰️
