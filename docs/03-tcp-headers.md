# 03 · Anatomía de las cabeceras TCP/IP y el handshake

> **Todo escaneo es, en el fondo, una conversación de cabeceras.** Cuando nmap dice
> "puerto abierto" o "filtrado", lo deduce de **qué flags TCP** vuelven (o no vuelven). Si
> entiendes la cabecera TCP/IP y el *handshake* de 3 vías, dejas de memorizar comandos y
> empiezas a **predecir** lo que verás. Este documento te da esa base, con diagramas, y
> conecta con `hotel` (M10) y `hping3`.

---

## 1. ¿Por qué empezar por las cabeceras?

Un paquete es un sobre con dos etiquetas apiladas:

```
┌─────────────────────────────────────────────────────────────┐
│  Cabecera IP   →  ¿de dónde a dónde? (IP origen/destino, TTL)│
│ ┌─────────────────────────────────────────────────────────┐ │
│ │  Cabecera TCP →  ¿qué puerto? ¿qué tipo de mensaje?      │ │
│ │                  (puertos, flags SYN/ACK/RST..., seq/ack)│ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │  Datos (payload)  →  banner, petición HTTP, etc.     │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

El escáner manipula esas etiquetas para **hacer preguntas** y lee las etiquetas de la
respuesta para **deducir el estado**. Vamos campo por campo.

---

## 2. La cabecera IP (los campos que nos importan)

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Ver|  IHL  |Tipo Servicio|         Longitud total              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Identificación       |Flags|     Desplaz. fragmento    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     TTL       |   Protocolo  |       Checksum cabecera        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     IP de ORIGEN                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     IP de DESTINO                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

Para el recon, dos campos brillan:

- **TTL (Time To Live):** un contador que **baja en 1 por cada router** que cruza el
  paquete. El **valor inicial** depende del SO emisor, así que el TTL que te llega delata
  el SO de origen (y cuántos saltos hubo):

  | SO emisor típico        | TTL inicial |
  |-------------------------|-------------|
  | Linux / macOS / BSD     | **64**      |
  | Windows                 | **128**     |
  | Routers / equipos de red| **255**     |

  > En `echo` (M08), el TTL de salida se **fuerza a 128** para imitar Windows. En `hotel`
  > (M10) leerás el TTL a mano con `hping3`. Detalle en [08](06-version-os-detection.md) y
  > [10](08-hping3.md).

- **Flags de fragmentación + Identificación:** permiten partir un paquete en trozos. La
  fragmentación (`nmap -f`) es una técnica de **evasión** que verás en
  [09](09-evasion-firewall.md) (M11).

---

## 3. La cabecera TCP, campo por campo

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Puerto de ORIGEN       |       Puerto de DESTINO       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Número de SECUENCIA (seq)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Número de ACUSE de recibo (ack)              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Offset|Reserv.|U|A|P|R|S|F|          Window (ventana)         |
|       |       |R|C|S|S|Y|I|                                   |
|       |       |G|K|H|T|N|N|                                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Checksum            |      Urgent Pointer           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  Opciones (MSS, window scale, ...)            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.1 Puertos de origen y destino
Identifican la conversación. El **destino** es el puerto que escaneas (22, 80, 443…). El
**origen** lo elige tu pila —y manipularlo (`-g 53`) es una técnica de evasión: ver M11.

### 3.2 Números de secuencia (seq) y acuse (ack)
TCP es fiable porque **numera cada byte**:

- **seq:** el número del primer byte que envías.
- **ack:** "ya recibí hasta aquí; espero el siguiente". Solo es válido si la flag **ACK**
  está activa.

En el handshake se usan para sincronizar ambos extremos (de ahí el "SYN" =
*synchronize*).

### 3.3 Las 6 flags de control (¡el alma del escaneo!)

Cada flag es **un bit**: activado (1) o no (0). Un paquete puede llevar varias a la vez.

| Flag | Nombre        | Significado en una frase                                      |
|------|---------------|--------------------------------------------------------------|
| **U**RG | Urgent     | "Hay datos urgentes" (rarísimo hoy).                         |
| **A**CK | Acknowledge| "Estoy acusando recibo"; el campo `ack` es válido.          |
| **P**SH | Push       | "Entrega estos datos a la app ya, no los almacenes".        |
| **R**ST | Reset      | "Corta esta conexión / no hay nada escuchando aquí".        |
| **S**YN | Synchronize| "Quiero **abrir** una conexión; sincronicemos secuencias".  |
| **F**IN | Finish     | "He terminado de enviar; cerremos ordenadamente".           |

Combinaciones que verás constantemente (notación de `hping3`):

```
S    = SYN            → "abre conexión"            (petición de inicio)
SA   = SYN + ACK      → "vale, abramos"            (PUERTO ABIERTO responde esto)
RA   = RST + ACK      → "aquí no escucha nadie"    (PUERTO CERRADO responde esto)
R    = RST            → "corta ya"
FPU  = FIN+PSH+URG    → paquete "Xmas" (escaneos exóticos)
(sin respuesta)       → FILTRADO (un firewall se lo tragó)
```

> **Esta tabla es, literalmente, cómo nmap deduce los estados.** Si entiendes `SA` vs `RA`
> vs silencio, entiendes el 90% del escaneo de puertos.

### 3.4 Window (ventana)
Cuántos bytes está dispuesto a recibir el emisor sin confirmación (control de flujo). Su
**valor inicial** también varía por SO, así que es **otra pista de huella de SO** junto al
TTL (lo usa `-O` de nmap; ver [08](06-version-os-detection.md)).

### 3.5 Opciones: MSS y compañía
La más famosa es **MSS (Maximum Segment Size)**: el mayor trozo de datos por segmento.
Aparece en el SYN inicial. El conjunto de opciones y su orden forman parte de la **firma
de pila** que delata el SO.

---

## 4. El handshake de 3 vías (3-way handshake)

Abrir una conexión TCP son **tres paquetes**. Este baile es la base del escaneo `-sT`
(connect) y de la mitad del `-sS` (SYN).

```
   Cliente (attacker)                         Servidor (p. ej. alpha:80)
        │                                              │
        │  (1)  ─────────  SYN  ──────────────────►    │   "quiero abrir;
        │        seq=x                                 │    mi secuencia es x"
        │                                              │
        │  (2)  ◄─────────  SYN, ACK  ─────────────    │   "vale; mi secuencia es y,
        │        seq=y  ack=x+1                         │    y reconozco tu x"
        │                                              │
        │  (3)  ─────────  ACK  ──────────────────►    │   "reconozco tu y;
        │        ack=y+1                                │    conexión ESTABLECIDA"
        │                                              │
        │ ===========  CONEXIÓN ABIERTA  ===========   │
```

- **`-sT` (TCP connect):** nmap completa los **3 pasos** (usa la pila del SO). Fiable, no
  necesita privilegios, pero **deja la conexión registrada** en el servidor.
- **`-sS` (SYN / half-open):** nmap envía el SYN, ve el **SYN/ACK** (→ abierto) y, en vez
  de completar con ACK, manda **RST** para abortar. Más rápido y sigiloso; necesita
  `NET_RAW` (que tu `attacker` ya tiene). Detalle en [04](04-tipos-de-escaneo.md).

### 4.1 ¿Y si el puerto está cerrado o filtrado?

```
PUERTO ABIERTO          PUERTO CERRADO           PUERTO FILTRADO
attacker → SYN          attacker → SYN           attacker → SYN
server   ← SYN,ACK      server   ← RST,ACK       (silencio... firewall DROP)
  ⇒ "open"                ⇒ "closed"               ⇒ "filtered"
```

> Esta es exactamente la diferencia que practicarás en `charlie` (M05/M06) y `hotel`
> (M10). Un firewall puede producir "closed" (RST, con `REJECT`) o "filtered" (silencio,
> con `DROP`). Ver [06](05-estados-de-puertos.md).

### 4.2 Cierre ordenado (FIN)

Para cerrar limpiamente, cada lado envía **FIN** y el otro lo **ACK**ea (un "cuádruple
apretón"). Por eso `FIN` aparece en escaneos exóticos: enviar un FIN a un puerto que nunca
se abrió provoca respuestas reveladoras según el SO.

---

## 5. De la teoría al paquete: `hping3`

`hping3` te deja **encender las flags que quieras** y mirar qué vuelve. Es el puente
perfecto entre esta teoría y `hotel` (M10). Ejemplos contra `hotel` (172.30.0.27):

```bash
# (a) SYN al 22 (open en hotel) → esperas SYN/ACK (flags=SA)
hping3 -S -p 22 -c 1 172.30.0.27

# (b) SYN al 80 (closed en hotel, REJECT con tcp-reset) → esperas RST/ACK (flags=RA)
hping3 -S -p 80 -c 1 172.30.0.27

# (c) SYN al 443 (filtered en hotel, DROP) → SIN respuesta (timeout)
hping3 -S -p 443 -c 1 172.30.0.27

# (d) FIN al 22 → respuesta según la pila; observa flags y compara con (a)
hping3 -F -p 22 -c 1 172.30.0.27
```

**Cómo leer la salida de `hping3`:**

```
len=46 ip=172.30.0.27 ttl=64 ... sport=22 flags=SA seq=0 win=64240 ...
        └─ IP origen   └─ TTL  └─ puerto    └─ FLAGS       └─ ventana
```

- **`flags=SA`** → SYN/ACK → **puerto abierto** (caso a).
- **`flags=RA`** → RST/ACK → **puerto cerrado** (caso b).
- **timeout / 0 paquetes recibidos** → **filtrado** (caso c).
- **`ttl=`** → pista de SO (recuerda la tabla del §2).
- **`win=`** → ventana TCP, otra pista de huella.

> En `hotel`, enumerar con cuidado estas respuestas (qué puerto da SA, cuál RA, cuál
> silencio) te llevará a descubrir un puerto "premio" con el flag de **M10 ·
> `RECON{...}`**. El cómo, paso a paso, está en [10 · hping3](08-hping3.md). Aquí
> solo te damos la **gramática** para leer cada paquete.

---

## 6. Cómo cada escaneo "habla" cabeceras (mapa rápido)

| Escaneo nmap | Envía            | Puerto abierto responde | Cerrado responde | Filtrado |
|--------------|------------------|--------------------------|------------------|----------|
| `-sT` connect| SYN (+handshake) | SYN/ACK → ACK            | RST/ACK          | timeout  |
| `-sS` SYN    | SYN              | SYN/ACK (nmap → RST)     | RST/ACK          | timeout  |
| `-sA` ACK    | ACK              | RST (→ "unfiltered")     | RST              | timeout  |
| `-sF` FIN    | FIN              | (silencio en muchos SO)  | RST              | timeout  |
| `-sU` UDP    | datagrama UDP    | respuesta UDP o silencio | ICMP port unreach| timeout  |

> El escaneo ACK (`-sA`) no distingue open/closed, pero **sí distingue filtrado de no
> filtrado**: por eso es oro para mapear reglas de firewall (M06).

---

## 7. Resumen

- Un paquete = **cabecera IP** (TTL, fragmentación) + **cabecera TCP** (puertos, flags,
  seq/ack, window, MSS) + datos.
- Las **6 flags** (URG/ACK/PSH/RST/SYN/FIN) son el idioma del escaneo: **SA = abierto**,
  **RA = cerrado**, **silencio = filtrado**.
- El **handshake de 3 vías** (SYN → SYN/ACK → ACK) sustenta `-sT` y `-sS`.
- **TTL** y **window** son pistas de huella de SO (M08).
- Con **`hping3`** enciendes flags a mano y lees la respuesta cruda: es la antesala de
  **hotel (M10)**.

> Con la cabecera dominada, ya puedes interpretar cualquier escaneo. Sigue con
> [04 · Escaneo de puertos](04-tipos-de-escaneo.md) para poner SYN y connect en acción, o
> salta a [10 · hping3](08-hping3.md) si quieres fabricar paquetes ya mismo.
