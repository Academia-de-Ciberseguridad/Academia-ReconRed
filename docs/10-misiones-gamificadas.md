# 10 · Dossier de Misiones — Operación Red Recon

> **Clasificado · Para los ojos del operador.** Esto es tu *dossier de campaña*: doce
> misiones (M01 … M12) que te llevarán de **Recluta** a **Maestro Recon**. Cada misión
> entrena una competencia real de reconocimiento, te concede **puntos** y, a veces, una
> **badge**. Aquí encontrarás el *briefing*, el objetivo y pistas progresivas —pero
> **no los flags**: el botín se gana sobre el terreno. Cuando lo extraigas, entrégalo en
> el [scoreboard](http://localhost:8080) para sumar.

---

## Cómo leer una ficha de misión

Cada misión incluye:

- **Rango / dificultad** — de ☆ (calentamiento) a ☆☆☆☆☆ (BOSS).
- **Briefing** — la narrativa inmersiva que pone en contexto el objetivo.
- **Objetivo** — host, IP y puerto(s) sobre los que operas.
- **Competencias** — qué habilidad de recon entrenas.
- **Puntos** — lo que sumas al resolverla.
- **Tipo de entrega** — `flag` (`RECON{...}`) o `answer` (palabra/número corto).
- **Pistas progresivas** — 1 o 2 empujones; úsalas solo si te atascas (en el scoreboard
  revelar una pista puede tener coste según configure el instructor).

> **Reglas de oro.** Trabaja **nativamente desde tu Kali** (usa `sudo` para SYN/UDP/OS/`hping3`).
> Ataca solo a los objetivos del lab (`alpha`…`hotel`, **172.30.0.21–.27**). El flag se
> encuentra, no se comparte.

### Tabla rápida de la campaña

| ID  | Misión              | Objetivo                 | Dificultad | Tipo   | Pts  | Badge        |
|-----|---------------------|--------------------------|------------|--------|------|--------------|
| M01 | Primer Contacto     | Subred 172.30.0.0/24     | ☆          | answer | 50   | —            |
| M02 | Puertas Abiertas    | alpha · 80/tcp           | ☆          | flag   | 100  | *first-blood\** |
| M03 | Identidades         | alpha · 80/tcp           | ☆☆         | answer | 100  | —            |
| M04 | El Tesoro de Redis  | bravo · 6379/tcp         | ☆☆         | flag   | 150  | —            |
| M05 | Estados Cuánticos   | charlie · 31337/tcp      | ☆☆☆        | flag   | 150  | —            |
| M06 | Cortafuegos al Desnudo | charlie · 443/tcp     | ☆☆☆        | answer | 150  | —            |
| M07 | Aguja en el Pajar   | delta · 9000–9049/tcp    | ☆☆☆        | flag   | 200  | —            |
| M08 | Huella Digital      | echo · TTL + 135/139/445 | ☆☆☆        | answer | 150  | —            |
| M09 | Territorio UDP      | foxtrot · 53/udp+tcp     | ☆☆☆☆       | flag   | 200  | `udp-diver`  |
| M10 | El Arte del Paquete | hotel · 7777/tcp         | ☆☆☆☆       | flag   | 250  | `packet-smith` |
| M11 | Operación Sigilo    | charlie / hotel · FW     | ☆☆☆☆       | answer | 200  | `ghost`      |
| M12 | BOSS — Mapa Total   | Toda la subred           | ☆☆☆☆☆      | flag   | 500  | `cartographer` |

> *`first-blood` se concede al **primer flag que resuelvas de cualquier misión**, no es
> exclusivo de M02. Total disponible en la campaña: **2 200 puntos**.

---

## M01 · Primer Contacto

- **Rango / dificultad:** Recluta · ☆ (calentamiento)
- **Objetivo:** Subred **172.30.0.0/24** (desde tu Kali, en 172.30.0.0/24)
- **Competencias:** descubrimiento de hosts (*ping sweep*), aritmética de red, lectura
  de la salida de un escaneo sin puertos.
- **Puntos:** 50 · **Tipo:** `answer`

> **Briefing.** Acabas de desplegarte en territorio desconocido. Antes de elegir un
> blanco, el Mando exige un censo: ¿cuántas máquinas están realmente **vivas** en la
> subred del laboratorio? Lanza un barrido de descubrimiento y reporta el número de
> equipos que responden. Cuidado con la aritmética de red: la dirección de red, la de
> *broadcast* y la pasarela no son "objetivos", aunque alguna pueda contestar. Cuenta a
> los que están realmente operativos.

**Qué observarás y por qué.** Un barrido `-sn` (ping scan) no toca puertos: solo envía
sondas de descubrimiento (ARP en red local, eco ICMP, etc.) y lista cada host que
responde con un `Host is up`. Como estás en el mismo segmento Docker, el descubrimiento
por ARP es muy fiable. Verás a `scoreboard`, los 7 objetivos y, según el matiz, también
la pasarela; el propio `attacker` no se cuenta a sí mismo. Ahí está el debate del conteo.

**Pistas progresivas**
1. Un barrido **sin escaneo de puertos** sobre toda la subred. Cuenta las líneas
   `Host is up`.
2. La pasarela (`.1`) puede contar o no según cómo definas "objetivo": el scoreboard
   acepta **ambas** lecturas. Piensa por qué la dirección de red y la de *broadcast* no
   son hosts.

---

## M02 · Puertas Abiertas

- **Rango / dificultad:** Recluta · ☆
- **Objetivo:** `alpha` (**172.30.0.21**) — **80/tcp**
- **Competencias:** recon web básico, lectura de cabeceras HTTP, *information disclosure*
  en ficheros de control (`/robots.txt`).
- **Puntos:** 100 · **Tipo:** `flag`

> **Briefing.** El host **ALPHA** expone un servidor web. Las webs siempre dejan migajas:
> ficheros de control, cabeceras reveladoras, comentarios olvidados... Localiza el
> servicio HTTP, inspecciona sus **cabeceras de respuesta** y los recursos "para robots"
> que casi nadie mira. Extrae la credencial de reconocimiento (formato `RECON{...}`).

**Qué observarás y por qué.** El puerto 80 responde un `200 OK`. El servidor incluye una
cabecera **`X-Recon-Flag`** no estándar (las cabeceras `X-*` son personalizadas y suelen
filtrar información), y el `/robots.txt` —pensado para indexadores— acaba siendo un mapa
de lo que alguien quería ocultar. Aquí el mismo botín aparece en los dos sitios.

**Pistas progresivas**
1. Descubre el puerto 80 y pide el `/robots.txt` con un cliente HTTP.
2. Las cabeceras también hablan: una petición que muestre solo cabeceras (`-I`) revela
   una cabecera con nombre `X-Recon-...`.

---

## M03 · Identidades

- **Rango / dificultad:** Explorador · ☆☆
- **Objetivo:** `alpha` (**172.30.0.21**) — **80/tcp**
- **Competencias:** detección de versión de servicio (`-sV`), interpretación de la
  columna SERVICE/VERSION.
- **Puntos:** 100 · **Tipo:** `answer` (una palabra, minúsculas)

> **Briefing.** Conocer el puerto no basta: hay que saber **qué** corre detrás. La
> detección de versión interroga al servicio para arrancarle su identidad. Determina qué
> software sirve el puerto 80 de **ALPHA** y reporta el **nombre del servicio** (una sola
> palabra, en minúsculas).

**Qué observarás y por qué.** Con detección de versión, nmap no se limita a decir
`open`: envía sondas y compara el banner/comportamiento contra su base de firmas. En la
columna **VERSION** verás el motor web y su número de versión; el **nombre del servicio**
(el software del servidor) es la respuesta. Fíjate también en que la cabecera `Server`
del HTTP coincide con lo que reporta nmap: dos vías, una misma identidad.

**Pistas progresivas**
1. Detección de versión limitada al puerto 80.
2. La respuesta es el **nombre del servidor web** (una palabra), tal como aparece en la
   columna SERVICE/VERSION.

---

## M04 · El Tesoro de Redis

- **Rango / dificultad:** Explorador · ☆☆
- **Objetivo:** `bravo` (**172.30.0.22**) — **6379/tcp**
- **Competencias:** identificación de servicio (`-sV`), **interacción** con un servicio
  expuesto, enumeración de Redis sin autenticación.
- **Puntos:** 150 · **Tipo:** `flag`

> **Briefing.** **BRAVO** ejecuta un **Redis sin autenticación**: un descuido clásico y
> peligrosísimo en el mundo real. Un servicio que habla es un servicio que se puede
> interrogar. Conéctate, enumera las claves y extrae el valor de la clave `flag`.

**Qué observarás y por qué.** Primero confirmarás con `-sV` que el 6379 es Redis (su
banner/respuesta a `PING` lo delata). Al conectar con su cliente nativo no te pide
contraseña: eso es lo que lo hace explotable. `KEYS *` te da el inventario de claves y un
`GET` sobre la clave correcta devuelve el botín. En `bravo` también hay banners
simulados de MySQL (3306) y PostgreSQL (5432): buen sitio para practicar `-sV` con varios
servicios a la vez.

**Pistas progresivas**
1. Identifica 6379/tcp con detección de versión; es un Redis.
2. Usa el cliente nativo de Redis para listar claves (`KEYS *`) y leer la que se llama
   `flag`.

---

## M05 · Estados Cuánticos

- **Rango / dificultad:** Operador · ☆☆☆
- **Objetivo:** `charlie` (**172.30.0.23**) — **31337/tcp** (oculto entre filtrados)
- **Competencias:** escaneo de **todo el rango de puertos** (`-p-`), distinguir un puerto
  abierto camuflado entre filtrados, lectura de banner.
- **Puntos:** 150 · **Tipo:** `flag`

> **Briefing.** **CHARLIE** esconde una puerta tras un muro de puertos filtrados. La
> mayoría están cerrados o tragados en silencio por el cortafuegos, pero uno muy **alto**
> permanece **ABIERTO** y disimulado. Encuéntralo y lee el banner que entrega.

**Qué observarás y por qué.** Si escaneas solo los puertos comunes, no lo verás: el
servicio se esconde en la zona alta (puerto "leet" 31337). Un escaneo de **todos** los
puertos lo revelará como `open` rodeado de `filtered`/`closed`. Al leer su banner
aparece el botín. Lección: los servicios "interesantes" rara vez están en el puerto
esperado.

**Pistas progresivas**
1. No te quedes en los puertos por defecto: escanea **todo** el rango de puertos.
2. Busca un `open` poco habitual entre `filtered` (zona alta, sabor *l33t*) y lee su
   banner.

---

## M06 · Cortafuegos al Desnudo

- **Rango / dificultad:** Operador · ☆☆☆
- **Objetivo:** `charlie` (**172.30.0.23**) — **443/tcp**
- **Competencias:** diferenciar `closed` vs `filtered`, entender REJECT (RST) frente a
  DROP (silencio).
- **Puntos:** 150 · **Tipo:** `answer` (un término de estado de nmap)

> **Briefing.** Un buen analista distingue un puerto **CERRADO** de uno **FILTRADO**: el
> primero te manda un RST cortés; el segundo se traga tus paquetes en silencio (DROP).
> Analiza el puerto **443** de **CHARLIE** y reporta su **estado exacto** según nmap.

**Qué observarás y por qué.** El puerto 80 de `charlie` está `closed`: el firewall hace
REJECT con `tcp-reset`, así que recibes un RST y nmap concluye "cerrado". El 443 está
bajo DROP: tus SYN desaparecen, no llega ni RST ni SYN/ACK, y tras los reintentos nmap
no puede afirmar "cerrado". Ese estado de "no sé, alguien me ignora" tiene un nombre
concreto en nmap, y es la respuesta. Comparar 80 y 443 lado a lado es la mejor forma de
*ver* la diferencia.

**Pistas progresivas**
1. Escanea 80 y 443 a la vez y compara la columna STATE.
2. Si nmap no recibe **ninguna** respuesta (ni RST ni SYN/ACK), el estado **no** es
   `closed`. ¿Cómo llama nmap a "sin respuesta por DROP"?

---

## M07 · Aguja en el Pajar

- **Rango / dificultad:** Operador · ☆☆☆
- **Objetivo:** `delta` (**172.30.0.24**) — rango **9000–9049/tcp** (50 señuelos)
- **Competencias:** enumeración de un rango ruidoso, comparación de banners, aislar la
  señal del ruido (*decoys*).
- **Puntos:** 200 · **Tipo:** `flag`

> **Briefing.** **DELTA** es ruido puro: cincuenta puertos señuelo **idénticos** para
> saturar tu escaneo y agotar tu paciencia. Pero uno de ellos **NO** es como los demás:
> su banner es distinto y guarda el premio. Enumera el rango, compara banners y **aísla
> la aguja**.

**Qué observarás y por qué.** Un `-sV` sobre el rango devuelve 50 servicios con el mismo
banner genérico de *decoy*. La táctica es comparar: si 49 dicen lo mismo y 1 dice algo
distinto, ese es tu objetivo. El puerto especial cae **dentro** del rango (sabor "9042",
guiño a Cassandra) pero su entrada gana al patrón del rango. Lección: ante ruido masivo,
**diferencia**, no leas uno a uno.

**Pistas progresivas**
1. Enumera el rango completo con detección de versión y mira los banners.
2. Casi todos devuelven el mismo banner `decoy`; **busca el que difiere** (está dentro
   del rango) y lee su banner.

---

## M08 · Huella Digital

- **Rango / dificultad:** Operador · ☆☆☆
- **Objetivo:** `echo` (**172.30.0.25**) — **TTL** + puertos **135/139/445**
- **Competencias:** *fingerprinting* de SO por TTL y por perfil de puertos, límites de
  `-O` en contenedores.
- **Puntos:** 150 · **Tipo:** `answer` (familia de SO, una palabra)

> **Briefing.** Todo sistema deja una huella. El **TTL** de los paquetes de respuesta y
> el perfil de puertos abiertos delatan la **familia de sistema operativo**. **ECHO**
> responde con un TTL muy concreto y abre puertos típicos de su estirpe. ¿Qué SO sugiere?
> Reporta la **familia** (una palabra).

**Qué observarás y por qué.** Linux suele responder con TTL inicial 64 y Windows con 128.
`echo` **fuerza su TTL de salida a 128** vía `iptables ... TTL --ttl-set 128`, y además
abre 135/139/445 (RPC/NetBIOS/SMB), un trío inconfundible. Dos señales independientes
apuntan a la misma familia. Nota didáctica: `-O` puede ser poco fiable dentro de
contenedores; por eso aquí el TTL + el perfil de puertos son la prueba más sólida.

**Pistas progresivas**
1. Mide el TTL de las respuestas (con `ping`/`hping3`) y mira qué puertos abre.
2. Un TTL de salida cercano a **128** y los puertos **135/139/445** apuntan a una familia
   concreta. Reporta su nombre (una palabra).

---

## M09 · Territorio UDP

- **Rango / dificultad:** Analista · ☆☆☆☆
- **Objetivo:** `foxtrot` (**172.30.0.26**) — **53/udp+tcp** (zona `recon.lab`)
- **Competencias:** escaneo **UDP**, enumeración DNS, registros TXT, NSE de DNS.
- **Puntos:** 200 · **Tipo:** `flag` · **Badge:** `udp-diver`

> **Briefing.** El mundo no es solo TCP. **FOXTROT** sirve DNS para la zona `recon.lab`.
> Los registros **TXT** son un cajón de sastre donde se esconden secretos. Enumera el DNS
> y recupera el registro TXT de `flag.recon.lab`.

**Qué observarás y por qué.** El escaneo UDP es lento y silencioso: sin respuesta, nmap
suele marcar `open|filtered` (ambigüedad propia de UDP). Confirmarás 53/udp y luego
**preguntarás directamente** al servidor DNS por el registro TXT. Los TXT no tienen
formato fijo, así que son el escondite perfecto para una cadena `RECON{...}`. Puedes
llegar por consulta DNS directa o por NSE de DNS: dos caminos, mismo botín. Completarla
te gana la badge **`udp-diver`**.

**Pistas progresivas**
1. Confirma 53/udp con un escaneo UDP del puerto.
2. Consulta el **TXT** de `flag.recon.lab` apuntando al servidor de `foxtrot` (consulta
   DNS directa o NSE `dns-*`).

---

## M10 · El Arte del Paquete

- **Rango / dificultad:** Analista · ☆☆☆☆
- **Objetivo:** `hotel` (**172.30.0.27**) — **7777/tcp**
- **Competencias:** *packet crafting* con **hping3**, lectura de flags TCP de respuesta
  (SYN/ACK, RST, silencio), correlación estado↔respuesta.
- **Puntos:** 250 · **Tipo:** `flag` · **Badge:** `packet-smith`

> **Briefing.** **HOTEL** solo entrega su secreto a quien domina las **cabeceras TCP**.
> Forja paquetes a mano con `hping3`, observa qué responde cada puerto (SYN/ACK, RST o
> silencio) y descubre el puerto abierto de alta numeración que guarda el flag.

**Qué observarás y por qué.** `hotel` es un laboratorio de respuestas TCP: el 22 está
abierto y responde **SYN/ACK** (`flags=SA`); el 80 está cerrado por REJECT y responde
**RST** (`flags=R`); el 443 está filtrado por DROP y **no responde** (timeout). Aprender a
leer esas tres reacciones es *toda* la teoría de escaneo en estado puro. El 7777 está
abierto: sonda con `hping3`, confírmalo por su SYN/ACK y luego léete su banner para sacar
el botín. Completarla te gana **`packet-smith`**.

**Pistas progresivas**
1. Sonda en modo SYN con `hping3` (unos pocos paquetes) y observa las flags de respuesta:
   `SA` = abierto, `R` = cerrado, nada = filtrado.
2. El 7777 está abierto; tras confirmarlo, **lee su banner** (con un cliente TCP) para
   extraer el flag.

---

## M11 · Operación Sigilo

- **Rango / dificultad:** Analista · ☆☆☆☆
- **Objetivo:** `charlie` / `hotel` — reglas de filtrado
- **Competencias:** **evasión** de cortafuegos por *source-port* "mágico" y por
  fragmentación, pensamiento ofensivo responsable.
- **Puntos:** 200 · **Tipo:** `answer` (número de puerto) · **Badge:** `ghost`

> **Briefing.** Algunos cortafuegos confían en ciertos **puertos de origen** y se
> confunden con paquetes **fragmentados**. La evasión clásica fija el puerto de origen a
> uno "mágico" (típicamente DNS) o fragmenta las sondas para atravesar las reglas. ¿Qué
> **número de puerto de origen** es el truco canónico de evasión? Repórtalo.

**Qué observarás y por qué.** Reglas mal escritas a veces permiten todo lo que "parece"
venir de un servicio de confianza. Fijar el puerto de origen (`--source-port` / `-g`) a
ese valor "mágico" puede colar tus sondas; fragmentar (`-f`) puede burlar inspecciones
simples. El número canónico es el del servicio **DNS**; el scoreboard también acepta los
puertos de **FTP** (20/21) porque algunos firewalls los tratan igual de laxos. El
instructor puede endurecer el criterio. Completarla te gana **`ghost`**.

> **Ética.** La evasión se practica **solo** contra sistemas propios o autorizados. Aquí
> es un ejercicio controlado; fuera del lab, sin permiso por escrito, es ilegal.

**Pistas progresivas**
1. Prueba a **fijar el puerto de origen** de tus sondas (`--source-port` / `-g`) o a
   **fragmentar** (`-f`) contra `charlie`/`hotel`.
2. El puerto "mágico" clásico está asociado al servicio **DNS**. (También se aceptan los
   de FTP, 20/21.)

---

## M12 · BOSS — Mapa Total

- **Rango / dificultad:** Especialista · ☆☆☆☆☆ (**BOSS**)
- **Objetivo:** Toda la subred — síntesis final
- **Competencias:** integración de **todo** lo aprendido; cierre de operación.
- **Puntos:** 500 · **Tipo:** `flag` · **Badge:** `cartographer`
- **Requisitos de desbloqueo:** **M02, M04, M05, M07, M08, M09 y M10** resueltas.

> **Briefing.** Reconocimiento casi completado, operador. Has cartografiado web,
> servicios, estados de puerto, firewall, señuelos, huella de SO, UDP/DNS y paquetes
> forjados a mano. Cuando hayas resuelto las misiones **requeridas**, el Mando
> desclasificará el **FLAG MAESTRO**. Reenvíalo aquí para cerrar la operación y ganar el
> rango de **Cartógrafo**.

**Qué observarás y por qué.** Esta misión no se "encuentra" en un host: se **gana**. El
scoreboard vigila tus resoluciones y, en cuanto completes los siete retos requeridos, te
**revela** el flag maestro en el propio formulario de M12. El ritual de cierre es
copiarlo y reenviarlo: una entrega ceremonial que sella la campaña. Vale **500 puntos** y
la badge **`cartographer`**.

**Pistas progresivas**
1. Completa las misiones requeridas (M02, M04, M05, M07, M08, M09, M10); el flag maestro
   se desbloquea solo entonces.
2. El scoreboard te mostrará el flag aquí mismo: cópialo y **reenvíalo** en este
   formulario para cerrar la operación.

---

## Sistema de rangos

Tus **puntos acumulados** determinan tu rango. Asciende resolviendo misiones:

| Puntos        | Rango              | Hito narrativo                                        |
|---------------|--------------------|-------------------------------------------------------|
| 0–99          | **Recluta**        | Te acabas de alistar. Aún hueles a manual.            |
| 100–299       | **Explorador**     | Ya sabes mirar puertos sin que te tiemble el pulso.   |
| 300–599       | **Operador**       | Distingues estados, lees banners, aíslas señuelos.    |
| 600–999       | **Analista**       | UDP, huella de SO y paquetes a mano: dominio sólido.  |
| 1000–1499     | **Especialista**   | El BOSS te respeta. Pocos llegan aquí.                |
| 1500+         | **Maestro Recon**  | Cartografías una red con los ojos cerrados.           |

> Con la campaña completa (2 200 pts) cruzas holgadamente el umbral de **Maestro Recon**.
> Cada flag y cada respuesta te acercan; no hace falta resolver en orden, salvo el BOSS.

---

## Badges (insignias)

Colecciónalas. Algunas son automáticas; otras dependen del instructor.

| Badge           | Cómo se gana                                                | Misión |
|-----------------|-------------------------------------------------------------|--------|
| `first-blood`   | Tu **primer flag** de cualquier reto                        | (la 1.ª)|
| `udp-diver`     | Bucear en UDP/DNS y sacar el TXT                            | M09    |
| `packet-smith`  | Forjar paquetes con hping3 y cobrar el botín               | M10    |
| `ghost`         | Atravesar el firewall con evasión (*source-port* / `-f`)   | M11    |
| `cartographer`  | Derrotar al BOSS y cerrar el Mapa Total                    | M12    |
| `speedrunner`   | Resolver **5 retos en menos de 30 min** (opcional/instructor) | —   |

---

> **Adelante, operador.** Levanta el lab, entra a `attacker`, abre el
> [scoreboard](http://localhost:8080) y empieza por **M01 · Primer Contacto**. La red te
> espera, y el rango de **Maestro Recon** no se gana solo. Buena caza.
