# 09 · Evasión de firewalls (responsable) — atravesar reglas en el lab

> **Operación Red Recon** · Módulo NSE, hping3 y evasión (parte C)
> **Nativo:** ejecutas desde tu Kali contra 172.30.0.21–.27 (SYN/UDP/OS y `hping3` con `sudo`).
> Objetivos de práctica: **charlie** (`172.30.0.23`) y **hotel** (`172.30.0.27`).
> Misión conectada: **M11 · Operación Sigilo** (badge `ghost`).

---

## ⚠️ Nota ética (léela antes de nada)

Las técnicas de este documento sirven para **comprender cómo un firewall puede ser
sorteado** y, por tanto, **cómo defenderlo mejor**. Las practicas **exclusivamente**
contra `charlie` y `hotel`, contenedores **propiedad del lab**, en una **red Docker
aislada** (`recon_net`). Usarlas contra sistemas de terceros sin autorización por
escrito es **ilegal**. El objetivo aquí es **didáctico y defensivo**: un operador que
entiende la evasión es el que sabe escribir reglas que **no** se dejan evadir.

> 🛡️ Recuerda la mentalidad de equipo azul: por cada técnica de evasión que aprendes,
> apunta **cómo la detectarías o bloquearías**. Eso es lo que separa a un profesional
> de un curioso.

---

## Briefing

Un firewall filtra paquetes según reglas: puerto destino, puerto **origen**,
protocolo, banderas, tamaño… La evasión consiste en **moldear tu paquete** para que
**no encaje** en la regla de bloqueo (o **sí encaje** en una regla de *accept*
demasiado permisiva). En este lab, charlie y hotel tienen reglas reales de iptables;
tú vas a aprender qué "disfraces" cambian el resultado.

| Técnica | Idea | Herramienta |
|---|---|---|
| Fragmentación | Partir el paquete para confundir filtros | `nmap -f` / `--mtu` |
| Decoys | Esconderte entre IPs señuelo | `nmap -D` |
| Puerto de origen | Disfrazarte de tráfico "de confianza" | `nmap -g` / `--source-port`; `hping3 -s` |
| Datos extra | Cambiar el tamaño/firma del paquete | `nmap --data-length` / `hping3 -d` |
| MAC falsa | Suplantar la dirección de capa 2 | `nmap --spoof-mac` |
| Checksum malo | Pasar filtros que ignoran checksums malos | `nmap --badsum` |
| Timing lento | Volar por debajo del radar de detección | `nmap -T0..T5`, `--scan-delay` |

---

## 1) Fragmentación: `-f` y `--mtu`

```bash
# -f : parte el paquete en fragmentos pequeños (~8 bytes de datos por fragmento)
nmap -sS -f -p 443 172.30.0.23

# -ff : fragmentos aún más pequeños
nmap -sS -ff -p 443 172.30.0.23

# --mtu : controla el tamaño de fragmento (múltiplo de 8)
nmap -sS --mtu 16 -p 443 172.30.0.23
```

**Idea y por qué:** algunos filtros antiguos o mal configurados toman la decisión
mirando solo el **primer fragmento** (donde está la cabecera). Si la información clave
(puerto, flags) queda repartida entre fragmentos, el filtro puede **no reensamblar** y
dejar pasar el tráfico. `--mtu` debe ser **múltiplo de 8**. En el lab, observa si el
estado de un puerto **filtered** cambia al fragmentar (depende de la regla concreta de
charlie/hotel).

> 🛡️ Defensa: un firewall moderno **reensambla** antes de decidir. Si la fragmentación
> "funciona", la lección es que el filtro era ingenuo.

---

## 2) Decoys: `-D`

```bash
# Mezcla tu IP real entre señuelos (ME = tu posición en la lista)
nmap -sS -D 172.30.0.50,172.30.0.51,ME,172.30.0.52 -p 22 172.30.0.23

# Señuelos aleatorios (RND)
nmap -sS -D RND:5 -p 22 172.30.0.23
```

**Idea y por qué:** el objetivo (o su IDS) ve **varias** IPs escaneándolo a la vez y le
cuesta saber **cuál es la real**. **No** oculta tu IP (sigue ahí), solo la **camufla
entre ruido**. En el lab sirve para entender cómo se "ensucia" un registro de detección.

> 🛡️ Defensa: correlación temporal y verificación de que los señuelos están "vivos" (a
> menudo son IPs muertas) delata el truco.

---

## 3) Puerto de origen "de confianza": `-g` / `--source-port` (¡clave para M11!)

Esta es la técnica central de **M11**.

```bash
# nmap: usa puerto ORIGEN 53 (parece tráfico de respuesta DNS)
nmap -sS --source-port 53 -p 22,80,443 172.30.0.23
nmap -sS -g 53 -p 22,80,443 172.30.0.27        # -g es el atajo de --source-port

# hping3: el puerto de origen se fija con -s (minúscula) y se desactiva el aleatorio con --keep
hping3 -S -s 53 --keep -p 443 -c 1 172.30.0.27
```

**Idea y por qué:** muchos firewalls antiguos **confían** en tráfico que *parece*
venir de servicios conocidos. Históricamente, las respuestas DNS llegan **desde el
puerto 53**, las de FTP-data **desde el 20**, etc. Una regla del tipo "permite todo lo
que venga del puerto origen 53" era común… y **explotable**: si **falsificas tu puerto
de origen** a 53, tu sonda **encaja** en esa regla *accept* y **atraviesa** el filtro.

### El criterio de **M11** (coherente con el scoreboard)

En este lab, charlie/hotel incluyen reglas de *accept* basadas en **puerto de origen**
para que la técnica sea **observable**. Concretamente, el filtro deja pasar tráfico
cuyo **puerto origen** sea uno de estos tres "mágicos":

- **`53`** → DNS (el clásico de evasión; **la respuesta canónica de M11**).
- **`21`** → FTP de control.
- **`20`** → FTP-data.

> 🎯 **Respuesta de M11:** el puerto fuente "mágico" por excelencia es **`53`** (DNS).
> El scoreboard, sin embargo, acepta también **`21`** y **`20`** porque las tres son
> reglas *accept* válidas del lab y todas demuestran que entendiste la técnica
> (`accept: ["53","21","20"]` en `challenges.yml`). Si tu experimento muestra que un
> puerto **filtered** se vuelve alcanzable al fijar `-g 53` (o `-g 21` / `-g 20`),
> **has resuelto M11**.

**Experimento que lo demuestra (charlie):**

```bash
# (1) Línea base: sin disfraz, observa el estado de los puertos filtrados
nmap -sS -p 22,80,443 172.30.0.23

# (2) Con puerto origen 53: ¿cambia algún estado de filtered a alcanzable?
nmap -sS -g 53 -p 22,80,443 172.30.0.23

# (3) Repite con 21 y 20 para confirmar que el lab acepta los tres
nmap -sS -g 21 -p 22,80,443 172.30.0.23
nmap -sS -g 20 -p 22,80,443 172.30.0.23
```

**Qué observas y por qué:** comparando (1) con (2)/(3), verás que el comportamiento del
puerto cambia cuando tu **puerto de origen** coincide con un puerto "de confianza" de
la regla *accept*. Esa diferencia **es** la pista de M11: el número de puerto fuente
que "delata" la regla (canónico **53**, también válidos **21/20**).

> 🛡️ Defensa: **nunca** confíes solo en el puerto de origen. Es trivial de falsificar.
> Un firewall con estado (*stateful*) rastrea la conexión real, no el puerto que el
> atacante dice usar.

---

## 4) Cambiar el tamaño/firma: `--data-length` y `--data`

```bash
# Añade 50 bytes de datos aleatorios a cada paquete (cambia su tamaño/firma)
nmap -sS --data-length 50 -p 22 172.30.0.27

# Equivalente fino en hping3: -d (tamaño del payload)
hping3 -S -p 22 -d 50 -c 1 172.30.0.27
```

**Idea y por qué:** algunas firmas de IDS buscan paquetes de un **tamaño exacto** (los
escaneos suelen enviar paquetes "vacíos" muy característicos). Añadir datos cambia esa
firma. En el lab es para que **veas** el campo de longitud cambiar y entiendas el
concepto, no porque charlie/hotel tengan un IDS que esquivar.

---

## 5) MAC falsa: `--spoof-mac`

```bash
# MAC aleatoria
nmap -sS --spoof-mac 0 -p 22 172.30.0.23

# MAC de un fabricante concreto (p.ej. "Apple") o una MAC literal
nmap -sS --spoof-mac Apple -p 22 172.30.0.23
nmap -sS --spoof-mac 00:11:22:33:44:55 -p 22 172.30.0.23
```

**Idea y por qué:** falsifica tu dirección de **capa 2**. Solo tiene efecto en la
**misma red local** (como la red Docker del lab; un router lo reescribe). Sirve para
camuflar tu equipo a ojos de la conmutación/registro de capa 2.

> 🛡️ Defensa: *port security* en el switch, inspección ARP, y correlación con la MAC
> esperada del puerto.

---

## 6) Checksum malo: `--badsum`

```bash
nmap -sS --badsum -p 22,443 172.30.0.23
```

**Idea y por qué:** envía paquetes con un **checksum TCP/UDP inválido**. Una pila
**correcta los descarta**; pero **algunos firewalls/IDS mal hechos** procesan (y
responden a) paquetes que un host real ignoraría. Si **recibes respuesta** a un
`--badsum`, sabes que **algo intermedio** (no el host final) está contestando: delata un
dispositivo de filtrado. En el lab es una sonda de diagnóstico didáctica.

---

## 7) Timing: `-T0..-T5` y `--scan-delay`

El **ritmo** es, en sí, una técnica de evasión: cuanto más lento escaneas, menos
"picos" generas y más difícil es que un detector por umbral te vea.

| Plantilla | Nombre | Velocidad / sigilo |
|---|---|---|
| `-T0` | paranoid | Lentísimo (un paquete cada varios minutos). Máximo sigilo |
| `-T1` | sneaky | Muy lento |
| `-T2` | polite | Lento, "educado" (menos carga al objetivo) |
| `-T3` | normal | **Por defecto** |
| `-T4` | aggressive | Rápido (redes fiables) |
| `-T5` | insane | Muy rápido (puede perder precisión) |

```bash
# Sigiloso: muy lento, difícil de detectar por umbral
nmap -sS -T1 -p 22,80,443 172.30.0.23

# Control fino del retardo entre sondas
nmap -sS --scan-delay 1s -p 22,80,443 172.30.0.23

# Rápido en la red fiable del lab (úsalo cuando NO practiques sigilo)
nmap -sS -T4 -p 22,80,443 172.30.0.27
```

**Idea y por qué:** `-T0/-T1` espacian las sondas para no superar el **umbral** de los
detectores ("X paquetes por segundo = escaneo"). `--scan-delay` te da control manual del
hueco entre sondas. En el lab no hay un IDS real persiguiéndote, así que **`-T0` es
innecesariamente lento**: úsalo una vez para *sentir* la diferencia y luego vuelve a un
ritmo razonable.

> 🛡️ Defensa: detección basada en **anomalías** y en correlación a largo plazo, no solo
> en umbrales por segundo. El sigilo por lentitud no es invisibilidad.

---

## 8) Laboratorio guiado de M11 (cópialo entero)

```bash
# === Línea base contra charlie (172.30.0.23) ===
nmap -sS -p 22,80,443 172.30.0.23 -oN /labs/charlie-base.txt

# === Puerto de origen "mágico": el corazón de M11 ===
nmap -sS -g 53 -p 22,80,443 172.30.0.23 -oN /labs/charlie-g53.txt
nmap -sS -g 21 -p 22,80,443 172.30.0.23 -oN /labs/charlie-g21.txt
nmap -sS -g 20 -p 22,80,443 172.30.0.23 -oN /labs/charlie-g20.txt

# Lo mismo a nivel paquete con hping3 (fija puerto origen 53)
hping3 -S -s 53 --keep -p 443 -c 1 172.30.0.27

# === Otras técnicas para entender el repertorio (contra hotel) ===
nmap -sS -f               -p 443 172.30.0.27    # fragmentación
nmap -sS --data-length 50 -p 22  172.30.0.27    # cambia firma de tamaño
nmap -sS --badsum         -p 22,443 172.30.0.27 # ¿responde algo intermedio?
nmap -sS -T1              -p 22,80,443 172.30.0.27  # sigilo por lentitud
```

**Cómo concluir M11:** compara `charlie-base.txt` con `charlie-g53.txt`. El **número de
puerto fuente** que cambia el comportamiento del firewall es tu respuesta. El canónico
es **`53`** (DNS); el scoreboard acepta también **`21`** y **`20`**.

**Checklist del operador (✔ módulo completado):**

- [ ] Entiendo y he probado **fragmentación** (`-f` / `--mtu`).
- [ ] Sé usar **decoys** (`-D`) y por qué **no** ocultan mi IP.
- [ ] Domino **`--source-port` / `-g`** (y `hping3 -s ... --keep`) — **clave de M11**.
- [ ] Sé que el puerto "mágico" canónico es **`53`** (válidos también **`21`/`20`**).
- [ ] He probado `--data-length`, `--spoof-mac` y `--badsum` y sé qué demuestran.
- [ ] Entiendo el **timing** (`-T0..T5`, `--scan-delay`) como sigilo por ritmo.
- [ ] Por cada técnica, sé apuntar **cómo la defendería** (mentalidad de equipo azul).

---

## Cierre

Has cerrado el **módulo NSE, hping3 y evasión (parte C)**. Ya sabes interrogar
servicios con **NSE** (doc 07), **fabricar paquetes** con hping3 (doc 08) y **moldearlos
para sortear filtros** de forma responsable (este doc). Con M11 te ganas el badge
`ghost` — pero el verdadero premio es entender que **toda evasión es una lección
defensiva**.

> *Evadir es entender la regla. Entender la regla es saber escribir una mejor.* 👻🛡️
