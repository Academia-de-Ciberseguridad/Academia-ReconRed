# 04 · Tipos de escaneo con Nmap — tu arsenal de sondas

> **Operación Red Recon** · Módulo de escaneo y estados (parte B)
> **Nativo:** ejecutas desde tu Kali contra 172.30.0.21–.27 (SYN/UDP/OS y `hping3` con `sudo`).
> Objetivos de práctica en este documento: **alpha** (`172.30.0.21`),
> **charlie** (`172.30.0.23`) y **foxtrot** (`172.30.0.26`).

---

## Briefing

Hasta ahora has hecho *host discovery*: saber **quién está vivo**. Ahora toca lo
siguiente: saber **qué puertas tiene cada casa y cómo reaccionan cuando llamas**.

Nmap no tiene "un escaneo". Tiene **un repertorio de técnicas**, cada una con una
forma distinta de tocar a la puerta (qué *flags* TCP pone en el paquete) y, por
tanto, con distinta visibilidad, sigilo, velocidad y permisos requeridos.

Piensa en cada técnica como una **herramienta del cinturón**: un destornillador no
sustituye a la llave inglesa. El operador que sabe *cuándo* usar cada una es el que
puntúa. En este documento aprendes el repertorio; en el documento 05 verás cómo se
traduce en **estados de puerto**.

> Recuerda el ritual del laboratorio: guarda siempre tus salidas.
> ```bash
> nmap -sS 172.30.0.21 -oA /labs/alpha-sS
> ```

---

## Mapa rápido del repertorio

| Técnica | Flag nmap | Qué envía | ¿Raw sockets / root? | Para qué brilla |
|---|---|---|---|---|
| TCP connect | `-sT` | Handshake completo (3-way) | **No** (usa la pila del SO) | Sin privilegios; el más "honesto" |
| TCP SYN | `-sS` | Solo SYN (*half-open*) | **Sí** | Rápido y algo más discreto. Por defecto con root |
| UDP | `-sU` | Datagramas UDP | **Sí** | Servicios UDP (DNS, SNMP, NTP) |
| TCP ACK | `-sA` | Solo ACK | **Sí** | Mapear **reglas de firewall** (filtered vs unfiltered) |
| Null | `-sN` | TCP sin **ningún** flag | **Sí** | Evasión; distinguir closed de open\|filtered |
| FIN | `-sF` | Solo FIN | **Sí** | Evasión |
| Xmas | `-sX` | FIN + PSH + URG (árbol de navidad) | **Sí** | Evasión |
| TCP Window | `-sW` | Como ACK, pero lee el *window* del RST | **Sí** | Variante del ACK: a veces deduce open/closed |

> **Regla de oro de privilegios:** **solo `-sT` funciona sin root.** Todas las
> demás técnicas construyen paquetes "a mano" (raw sockets) y necesitan
> privilegios. En este laboratorio el contenedor **attacker** tiene las
> capabilities **NET_RAW** y **NET_ADMIN**, así que puedes usarlas todas. Fuera del
> lab, ejecútalas con `sudo`.

---

## 1) `-sT` — TCP connect (el handshake completo)

Nmap pide al **sistema operativo** que abra la conexión con la llamada `connect()`,
exactamente igual que lo haría un navegador. Si la conexión se completa
(SYN → SYN/ACK → ACK), el puerto está **open**.

```bash
# Connect scan a alpha, mostrando el motivo de cada decisión
nmap -sT --reason 172.30.0.21
```

**Qué observas y por qué:**

- `22/tcp open ssh` y `80/tcp open http`: el handshake se completó. Con `--reason`
  verás `syn-ack` como razón → llegó el SYN/ACK del objetivo.
- Como Nmap completa el *three-way handshake*, **el servicio puede registrar la
  conexión** (deja más rastro que `-sS`). Es el menos sigiloso de los "normales".
- Ventaja decisiva: **no necesita privilegios**. Es tu plan B si algún día no tienes
  raw sockets.

> **Cuándo usar `-sT`:** cuando no tienes root, o cuando los raw sockets están
> capados. En el lab funciona perfectamente porque alpha tiene servicios reales.

---

## 2) `-sS` — SYN scan (*half-open*, el caballo de batalla)

Nmap envía **solo el SYN** y espera respuesta:

- Llega **SYN/ACK** → puerto **open**. Nmap responde con **RST** para cortar antes
  de completar el handshake (de ahí *half-open*): la conexión nunca se establece del
  todo.
- Llega **RST** → puerto **closed**.
- **No llega nada** (tras reintentos) → **filtered**.

```bash
# SYN scan a alpha (la técnica por defecto cuando eres root)
nmap -sS --reason 172.30.0.21
```

**Qué observas y por qué:**

- Resultados equivalentes a `-sT` en open/closed, pero **más rápido** y dejando
  menos rastro (no completa la conexión).
- Con `--reason`: `syn-ack` (open), `reset` (closed), `no-response` (filtered).
- Es el escaneo **por defecto** de Nmap cuando se ejecuta con privilegios. Si lanzas
  `nmap 172.30.0.21` como root, **estás haciendo `-sS`**.

> **Cuándo usar `-sS`:** casi siempre que tengas privilegios. Rápido, fiable y
> distingue limpiamente los tres estados básicos.

---

## 3) `-sU` — UDP scan (el territorio lento y traicionero)

UDP no tiene handshake. Nmap envía un datagrama y razona así:

- Llega una **respuesta UDP** → **open**.
- Llega **ICMP port-unreachable (tipo 3, código 3)** → **closed**.
- **No llega nada** → **open|filtered** (¡ambigüedad!). Nmap no puede distinguir si
  el puerto está abierto y simplemente calla, o si un firewall se comió el paquete.

```bash
# UDP scan dirigido a los puertos clásicos de foxtrot (no escanees 65535 UDP)
nmap -sU --reason -p 53,123,161 172.30.0.26
```

**Qué observas y por qué:**

- `53/udp`, `123/udp` y `161/udp` aparecen **open**: en foxtrot, dnsmasq (53) y
  portsrv (123 NTP-like, 161 SNMP-like) **responden** un datagrama. Esa respuesta es
  la que saca al puerto del limbo `open|filtered`.
- Es **mucho más lento** que TCP: ante el silencio, Nmap **reintenta con timeouts**
  para reducir falsos positivos. Por eso **acotamos con `-p`** en lugar de barrer
  todo el espacio UDP.
- Requiere raw sockets (root). En el lab ya tienes NET_RAW.

> **Cuándo usar `-sU`:** cuando buscas servicios UDP (DNS, SNMP, NTP, TFTP).
> **Siempre** con `-p` acotado y, si quieres confirmar versiones, añade `-sV`
> (ver doc 06). Esta es tu técnica para la **misión M09** (UDP/DNS).

---

## 4) `-sA` — ACK scan (el detector de cortafuegos)

`-sA` **no busca puertos abiertos**. Busca **reglas de firewall**. Envía un paquete
con **solo el flag ACK** (como si formara parte de una conexión ya existente) y mira
qué vuelve:

- Llega **RST** → el puerto es **unfiltered** (el paquete llegó hasta la pila TCP,
  que no reconoce la conexión y responde RST). *Unfiltered* ≠ open: solo significa
  "no hay firewall bloqueando".
- **No llega nada** (o ICMP de inalcanzable) → **filtered** (un firewall *stateful*
  descartó el ACK).

```bash
# ACK scan a charlie: ¿qué puertos están detrás de un firewall?
nmap -sA --reason -p 22,80,443,8000 172.30.0.23
```

**Qué observas y por qué en charlie:**

- `22/tcp` y `80/tcp` → **unfiltered** (`reset`): no hay regla iptables que los tape,
  así que el ACK provoca un RST. (Que sean unfiltered **no** te dice si están open o
  closed; eso lo dice el SYN scan).
- `443/tcp` y `8000/tcp` → **filtered** (`no-response`): charlie tiene un
  `iptables -A INPUT -p tcp --dport 443 -j DROP` (y lo mismo para 8000). El ACK cae
  en el agujero negro del DROP y no vuelve nada.

> **Cuándo usar `-sA`:** para **mapear el cortafuegos**, no los servicios. Combínalo
> con un `-sS` para tener la foto completa: `-sS` dice *open/closed/filtered* y `-sA`
> confirma *dónde hay reglas*. Esta es la técnica estrella de la **misión M06**
> (cortafuegos al desnudo).

---

## 5) `-sN` / `-sF` / `-sX` — Null, FIN y Xmas (la familia sigilosa)

Estas tres técnicas se basan en una regla del RFC 793: **un puerto cerrado debe
responder RST a cualquier paquete TCP "raro"; un puerto abierto debe ignorarlo.**

- `-sN` **Null scan**: paquete TCP **sin ningún flag**.
- `-sF` **FIN scan**: paquete con **solo FIN**.
- `-sX` **Xmas scan**: paquete con **FIN + PSH + URG** (el paquete "iluminado como un
  árbol de navidad").

La lógica de interpretación es idéntica en las tres:

- Llega **RST** → **closed**.
- **No llega nada** → **open|filtered** (no se puede distinguir: tanto un puerto
  abierto que calla como un firewall que descarta dan el mismo silencio).
- Llega **ICMP unreachable** → **filtered**.

```bash
# Trío sigiloso contra charlie (compáralos con el -sS de open/closed)
nmap -sN --reason -p 22,80,443 172.30.0.23
nmap -sF --reason -p 22,80,443 172.30.0.23
nmap -sX --reason -p 22,80,443 172.30.0.23
```

**Qué observas y por qué en charlie:**

- `80/tcp` → **closed** (`reset`): nadie escucha en 80 y no hay regla, así que el
  kernel responde RST a cualquiera de los tres paquetes raros.
- `22/tcp` → **open|filtered** (`no-response`): el puerto abierto **ignora** el
  paquete sin handshake, así que Nmap no recibe RST y no puede confirmar "open" a
  secas.
- `443/tcp` → **open|filtered** también, pero aquí por el **DROP** del firewall.

> **Aviso de realismo:** estas técnicas asumen una pila TCP "de manual". **Windows,
> muchos firewalls y algunos balanceadores responden RST a TODO**, lo que rompe la
> distinción y hace que todo parezca "closed". Por eso son técnicas de **nicho**, no
> de uso diario.

> **Cuándo usar Null/FIN/Xmas:** cuando quieres **evadir** filtros simples que solo
> bloquean SYN, o sondear pilas "de libro". En el lab te sirven para **ver con tus
> propios ojos** la diferencia entre `closed` (RST) y `open|filtered` (silencio).
> Conecta con la **misión M11** (evasión).

---

## 6) `-sW` — Window scan (el primo astuto del ACK)

`-sW` envía el mismo paquete que `-sA` (solo ACK), pero en lugar de fijarse en *si*
llega un RST, se fija en el **tamaño de ventana TCP (window)** de ese RST. En algunas
pilas antiguas, un RST con *window* > 0 delataba un puerto **open** y *window* = 0
uno **closed**.

```bash
# Window scan a charlie (compáralo mentalmente con -sA)
nmap -sW --reason -p 22,80,443 172.30.0.23
```

**Qué observas y por qué:**

- En pilas modernas (Linux actual, que es lo que corre bajo los contenedores del
  lab) **el truco del window ya no funciona de forma fiable**: lo normal es que
  `-sW` clasifique los puertos que responden RST como **closed** y los que no
  responden como **filtered**, igual que un ACK scan "tonto".
- Por eso `-sW` es hoy una **curiosidad histórica**: ilustra cómo Nmap exprime cada
  bit de la respuesta, pero rara vez aporta más que `-sA`.

> **Cuándo usar `-sW`:** casi nunca en producción. En el lab, úsalo para **comparar**
> su salida con `-sA` y entender que **no todos los trucos sobreviven** a las pilas
> TCP modernas.

---

## Privilegios y *raw sockets*: el porqué técnico

- **`-sT`** delega en la pila del SO (`connect()`), por eso **no** necesita
  privilegios: el kernel ya tiene permiso para abrir sockets normales.
- **El resto** (`-sS`, `-sU`, `-sA`, `-sN/-sF/-sX`, `-sW`) **fabrica paquetes TCP/UDP
  a medida** (con flags concretos) y los inyecta por debajo de la pila. Eso requiere
  **raw sockets**, que en Linux exige la capability **CAP_NET_RAW** (o ser root).
- En **Operación Red Recon**, el contenedor **attacker** ya trae **NET_RAW** y
  **NET_ADMIN** declaradas en `docker-compose.yml`, así que **no necesitas `sudo`**
  dentro del lab. Si replicas estas técnicas en tu máquina, antepón `sudo`.

Comprueba si tienes privilegios para raw sockets:

```bash
# Si esto NO te pide permisos y funciona, tienes raw sockets disponibles
nmap -sS -p 22 172.30.0.21
```

---

## Rendimiento: que un escaneo no se eternice

Más técnica no es "más mejor": cada una tiene un coste.

- **TCP (`-sS`/`-sT`)** es rápido: un SYN o un handshake bastan para decidir.
- **UDP (`-sU`)** es **lento** por diseño (silencio = reintentos con timeouts).
  Acótalo siempre con `-p`.
- **Acota puertos** con `-p` (`-p 22,80,443`) o usa `-F` (los ~100 puertos más
  comunes) cuando solo quieras una foto rápida.
- **Plantillas de temporización** `-T0` (paranoico/lento) … `-T5` (insano/rápido).
  Por defecto `-T3`. En el lab aislado puedes subir a `-T4` sin miedo:

```bash
# Rápido pero razonable: -T4, solo puertos comunes, con motivo
nmap -sS -T4 -F --reason 172.30.0.21
```

- **Evita** barridos masivos de UDP (`-sU -p-`): pueden tardar horas. Para delta y
  sus 50 decoys (documento de timing), verás por qué el control del ritmo importa.

> **Consejo de operador:** empieza estrecho y ve abriendo. Un `-sS -F` te da una foto
> en segundos; luego profundizas con `-sV`, `-sU` o `-sA` solo donde haga falta.

---

## Laboratorio guiado (encadénalo)

```bash
# 1) Connect vs SYN en alpha: mismo resultado, distinto coste y rastro
nmap -sT --reason -p 22,80,8080 172.30.0.21 | tee /labs/alpha-sT.txt
nmap -sS --reason -p 22,80,8080 172.30.0.21 | tee /labs/alpha-sS.txt

# 2) ACK scan: revela el firewall de charlie (filtered vs unfiltered)
nmap -sA --reason -p 22,80,443,8000 172.30.0.23 | tee /labs/charlie-sA.txt

# 3) Trío sigiloso: ve la diferencia closed (RST) vs open|filtered (silencio)
nmap -sN --reason -p 22,80,443 172.30.0.23 | tee /labs/charlie-sN.txt

# 4) UDP en foxtrot: territorio lento, acota siempre con -p
nmap -sU --reason -p 53,123,161 172.30.0.26 | tee /labs/foxtrot-sU.txt
```

**Checklist del operador (✔ antes de pasar al doc 05):**

- [ ] Sé decir, de memoria, **qué flag TCP** envía cada técnica.
- [ ] Entiendo **por qué solo `-sT`** funciona sin privilegios.
- [ ] Sé que **`-sA` mapea firewall**, no servicios.
- [ ] Sé por qué **UDP es lento** y siempre lo acoto con `-p`.
- [ ] Distingo **closed (RST)** de **open|filtered (silencio)**.

---

## Próxima parada

En el **documento 05 · Estados de puertos** desmenuzamos qué respuesta de red
(SYN/ACK, RST, *drop*) produce cada estado, y montamos el laboratorio práctico
contra **charlie** que conecta directamente con las misiones **M05** y **M06**.

> *El novato lanza un escaneo. El operador elige la sonda correcta.* 🎯
