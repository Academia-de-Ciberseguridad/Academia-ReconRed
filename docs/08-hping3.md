# 08 · `hping3` a fondo — fabrica tus propios paquetes

> **Operación Red Recon** · Módulo NSE, hping3 y evasión (parte C)
> **Nativo:** ejecutas desde tu Kali. `hping3` y los escaneos en crudo van con `sudo`.
> Objetivo estrella de este documento: **hotel** (`172.30.0.27`, `22/80/443/7777`).
> Misión conectada: **M10 · El Arte del Paquete** (`packet-smith`).

---

## Briefing

Nmap decide por ti qué paquete enviar. `hping3` te da **el bisturí**: tú eliges la
capa, las **flags TCP**, el puerto, el TTL, la ventana, los datos… y miras **byte a
byte** qué vuelve. Si el doc 03 te dio la *gramática* de las cabeceras, este te enseña
a **escribirlas a mano**.

`hping3` es un generador/analizador de paquetes TCP/IP de línea de comandos. Por
defecto trabaja "a lo `ping`", pero enviando **segmentos TCP** en lugar de ICMP. Esa es
la magia: un "ping" que habla TCP y te deja encender cualquier flag.

> 🎮 **Recompensa del módulo:** enumerando **hotel** paquete a paquete descubrirás un
> puerto "premio" (`7777`) con la pista de **M10**. Te ganas el badge `packet-smith`.

---

## 1) Modos de `hping3` (qué tipo de paquete fabricas)

`hping3` elige el **protocolo base** con un modo. Solo uno a la vez:

| Modo | Flag | Qué envía | Para qué |
|---|---|---|---|
| **TCP** (por defecto) | *(ninguno)* | Segmentos TCP | El modo estrella del recon de puertos |
| **RAW IP** | `-0` / `--rawip` | Paquetes IP "en crudo" | Experimentos de bajo nivel |
| **ICMP** | `-1` / `--icmp` | Mensajes ICMP (echo, etc.) | "ping" clásico, host discovery |
| **UDP** | `-2` / `--udp` | Datagramas UDP | Sondas UDP a mano |
| **SCAN** | `-8` / `--scan` | Barrido de puertos integrado | Escanear rangos rápido |
| **LISTEN** | `-9` / `--listen` | Modo escucha (sniffer de firma) | Recibir datos "ocultos" |

```bash
# TCP es el modo por defecto: esto ya envía un segmento TCP, no un ping ICMP
hping3 -S -p 22 -c 1 172.30.0.27

# ICMP explícito (equivalente a un ping)
hping3 -1 -c 1 172.30.0.27

# UDP al 161 de foxtrot
hping3 -2 -p 161 -c 1 172.30.0.26
```

### Modo SCAN (`-8`) — barrido integrado

```bash
# Escanea una lista/rango de puertos de hotel de una vez
hping3 -8 22,80,443,7777 -S 172.30.0.27
hping3 -8 1-1000 -S 172.30.0.27        # rango completo
```

`-8` recorre los puertos y te resume cuáles responden; es el "modo escáner" de hping3.
Para el detalle fino de M10, sin embargo, preferimos lanzar paquetes **uno a uno** y
leer cada respuesta.

---

## 2) Las flags TCP a mano

Aquí está el núcleo. Cada letra **enciende un bit** de la cabecera TCP (repasa el doc
03 §3.3). Puedes combinarlas.

| Opción | Flag TCP | "Frase" |
|---|---|---|
| `-S` | **SYN** | "quiero abrir una conexión" |
| `-A` | **ACK** | "acuso recibo" |
| `-F` | **FIN** | "he terminado, cerremos" |
| `-R` | **RST** | "corta esto ya" |
| `-P` | **PSH** | "entrega los datos ya" |
| `-U` | **URG** | "hay datos urgentes" |

```bash
# SYN puro (la sonda de recon por excelencia)
hping3 -S -p 22 -c 1 172.30.0.27

# Combinar flags: SYN + ACK (raro como sonda, útil para entender respuestas)
hping3 -S -A -p 80 -c 1 172.30.0.27

# Paquete "Xmas" a mano: FIN + PSH + URG
hping3 -F -P -U -p 22 -c 1 172.30.0.27
```

---

## 3) Opciones de control que vas a usar siempre

| Opción | Qué hace | Ejemplo |
|---|---|---|
| `-p <puerto>` | Puerto **destino** | `-p 443` |
| `++` | **Incrementa** el puerto destino en cada envío | `-p ++22` |
| `-c <n>` | Envía **n** paquetes y para | `-c 1` |
| `--ttl <n>` | Fija el **TTL** del paquete saliente | `--ttl 64` |
| `-w <n>` | Tamaño de **ventana** (window) | `-w 64240` |
| `-d <n>` | **Tamaño** del payload (datos) en bytes | `-d 64` |
| `-E <fichero>` | Lee el payload de un fichero | `-E datos.bin` |
| `-a <ip>` | **Spoofear** la IP de origen | `-a 172.30.0.99` |
| `-V` | Salida **verbose** (muestra la cabecera completa) | |

### `++` — incremento automático de puerto

```bash
# Empieza en 20 e incrementa el puerto destino en cada paquete: 20,21,22,...
hping3 -S -p ++20 -c 5 172.30.0.27
```

Esto te permite barrer un rango "a mano" sin el modo `-8`, viendo cada respuesta
individual. Muy didáctico para ver **dónde cambia el comportamiento** (open → closed →
filtered).

### `-c` — controla cuántos paquetes envías

Sin `-c`, `hping3` envía **indefinidamente** (como `ping` sin `-c`). En el lab,
**siempre** usa `-c 1` (o un número pequeño) para sondas puntuales y no generar ruido
innecesario. Corta con `Ctrl-C` si te dejas uno corriendo.

### `--ttl`, `-w`, `-d` — moldea la cabecera

```bash
# Fija TTL=128 (aparenta Windows) y ventana 8192
hping3 -S -p 22 --ttl 128 -w 8192 -c 1 172.30.0.27

# Adjunta 100 bytes de payload de relleno
hping3 -S -p 80 -d 100 -c 1 172.30.0.27
```

Estas opciones son la base de la **evasión** (doc 09): cambiar TTL, ventana, tamaño de
datos y puerto de origen altera la "firma" de tus paquetes.

---

## 4) Spoofing de origen (`-a`) y por qué **no recibes respuesta**

```bash
# Finge venir de 172.30.0.99 (una IP que no eres tú)
hping3 -a 172.30.0.99 -S -p 22 -c 1 172.30.0.27
```

Aquí hay una lección crucial. Cuando spoofeas la IP de origen con `-a`:

1. Tu paquete sale con **IP origen = 172.30.0.99** (no la tuya, `172.30.0.1`).
2. hotel responde… pero envía el **SYN/ACK a `172.30.0.99`**, no a ti.
3. **Tú nunca ves la respuesta**, porque viaja a la IP suplantada.

> 🧠 **Por qué importa:** el spoofing sirve para **ocultar tu origen** o para técnicas
> avanzadas (como el *idle/zombie scan*, donde un tercer host "delata" la respuesta vía
> su IP-ID). Pero para un escaneo normal es inútil: **si no eres tú quien recibe la
> respuesta, no aprendes nada del puerto**. En el lab, comprueba que con `-a` el campo
> de "paquetes recibidos" queda en **0**: es la prueba viva de este concepto.

> 🔒 **Nota ética:** el spoofing de IP solo es legítimo en una red de tu propiedad y
> aislada como este lab. Falsificar el origen contra terceros es ilegal en la mayoría
> de jurisdicciones. Lo practicas aquí para **entenderlo**, no para usarlo fuera.

---

## 5) Cómo leer la respuesta de `hping3` (la regla de oro)

Cada respuesta TCP que recibes lleva un campo **`flags=`**. Ese campo **es** el
veredicto del estado del puerto:

```
len=46 ip=172.30.0.27 ttl=64 DF id=0 sport=22 flags=SA seq=0 win=64240 rtt=0.3 ms
        └─ IP origen   └─TTL      └─ puerto   └─ FLAGS   └─ seq    └─ ventana
```

| Lo que ves | Significado | Estado del puerto |
|---|---|---|
| **`flags=SA`** | SYN/ACK → "vale, abramos" | **OPEN** |
| **`flags=RA`** | RST/ACK → "aquí no escucha nadie" | **CLOSED** |
| **(nada / timeout)** | El paquete fue tragado por un firewall (DROP) | **FILTERED** |

Otros campos que delatan al objetivo:

- **`ttl=`** → pista de SO (64 ≈ Linux, 128 ≈ Windows; ver doc 06).
- **`win=`** → ventana TCP, otra pista de huella de pila.
- **`id=`** → IP-ID, relevante para escaneos avanzados.

Al final de la ejecución, `hping3` resume cuántos paquetes **envió** y cuántos
**recibió**. Si "received = 0" tras enviar a un puerto, normalmente es **filtered**
(silencio) … o estás **spoofeando** (§4).

---

## 6) Laboratorio guiado contra **hotel** (M10)

hotel (`172.30.0.27`) es el campo de tiro de este documento. Su mapa (del LAB-SPEC):

| Puerto hotel | Estado | Respuesta esperada con `-S` |
|---|---|---|
| `22/tcp` | **open** (banner) | `flags=SA` (SYN/ACK) |
| `80/tcp` | **closed** (REJECT tcp-reset) | `flags=RA` (RST/ACK) |
| `443/tcp` | **filtered** (DROP) | **sin respuesta** (timeout) |
| `7777/tcp` | **open** (banner con la pista de M10) | `flags=SA` → ¡investiga! |

### Paso 1 · Sonda SYN puerto a puerto (lee cada `flags=`)

```bash
# 22 -> esperas SA (open)
hping3 -S -p 22 -c 1 172.30.0.27

# 80 -> esperas RA (closed: REJECT con tcp-reset)
hping3 -S -p 80 -c 1 172.30.0.27

# 443 -> esperas SILENCIO (filtered: DROP). hping3 quedará esperando; corta con Ctrl-C
hping3 -S -p 443 -c 1 172.30.0.27

# 7777 -> esperas SA (open) ... este es el puerto "premio"
hping3 -S -p 7777 -c 1 172.30.0.27
```

**Qué observas y por qué:**

- `22` y `7777` devuelven **`flags=SA`**: hay servicio escuchando.
- `80` devuelve **`flags=RA`**: el host está vivo pero rechaza (RST) por la regla
  `REJECT --reject-with tcp-reset`.
- `443` **no responde**: la regla `DROP` se traga el paquete; "received = 0" = filtered.

### Paso 2 · Barrido con incremento (`++`) para ver el patrón

```bash
# Recorre 22..27 y luego salta tú a los puertos altos; observa el cambio de comportamiento
hping3 -S -p ++22 -c 6 172.30.0.27
```

### Paso 3 · Confirmar TTL y ventana (huella)

```bash
# Lee ttl= y win= en la respuesta del 22 (apoya el módulo de OS/TTL)
hping3 -S -p 22 -c 1 -V 172.30.0.27
```

### Paso 4 · Saquear el puerto "premio" (la pista de M10)

`hping3` confirma que `7777` está **open**, pero la **pista** vive en su **banner**.
Para leer datos de aplicación, conecta con una herramienta de texto:

```bash
# Lee el banner de 7777 -> ahí está la pista de M10 (no se transcribe aquí)
nc 172.30.0.27 7777
```

> 🔒 **Solucionario aparte:** el flag exacto de M10 **no** se escribe en esta teoría.
> hping3 te dice *dónde mirar* (qué puerto está open y oculto entre cerrados/filtrados);
> el valor lo lees tú en el banner de `7777` y lo confirmas, si hace falta, en el
> documento solucionario.

---

## 7) Tabla-resumen para grabar a fuego

| Quieres… | Opción `hping3` | Pista clave |
|---|---|---|
| Enviar SYN/ACK/FIN/RST/PSH/URG | `-S` / `-A` / `-F` / `-R` / `-P` / `-U` | enciendes el bit a mano |
| Elegir el puerto destino | `-p <n>` (o `-p ++<n>` para incrementar) | |
| Limitar el nº de paquetes | `-c <n>` | usa siempre `-c 1` en el lab |
| Cambiar protocolo base | `-0`/`-1`/`-2`/`-8`/`-9` | raw/icmp/udp/scan/listen |
| Moldear cabecera | `--ttl`, `-w`, `-d` | base de la evasión (doc 09) |
| Suplantar origen | `-a <ip>` | **no verás la respuesta** (§4) |
| Interpretar la respuesta | campo **`flags=`** | **SA=open · RA=closed · silencio=filtered** |

---

## Cierre

Ya no dependes de que Nmap decida por ti: con `hping3` **fabricas el paquete**,
**enciendes las flags** y **lees la cabecera de vuelta**. Esa es la mentalidad del
`packet-smith`, y es exactamente lo que resuelve **M10** en hotel.

En el siguiente documento llevamos estas mismas opciones (`--ttl`, `-d`, puerto de
origen, fragmentación) un paso más allá: las usamos para **atravesar reglas de
firewall** de forma responsable → [09 · Evasión de firewalls](09-evasion-firewall.md).

> *El que fabrica el paquete, controla la pregunta.* 🛠️
