# 02 · Descubrimiento de hosts (M01 · Primer Contacto)

> **Primera regla del recon:** no escanees lo que no existe. Antes de mirar puertos,
> averigua **qué direcciones están vivas**. En este documento aprenderás las técnicas de
> descubrimiento de `nmap` (`-sn`, `-PR`, `-PS/-PA/-PE/-PP`, `-Pn`), cuándo usar cada una,
> por qué el **gateway** y las direcciones de **red/broadcast** importan para *contar*
> bien, y harás el ejercicio guiado de **M01** (sin spoilers de la respuesta final).

---

## 1. ¿Qué es el descubrimiento de hosts?

El descubrimiento (*host discovery* o *ping sweep*) responde a una sola pregunta:

> De todo un rango de direcciones, ¿cuáles corresponden a una máquina que **responde**?

`nmap` lo hace enviando **sondas** (probes) y observando quién contesta. Según el tipo de
sonda, golpeas distintas capas de la pila de red.

```bash
# Barrido de descubrimiento: SOLO host discovery, sin escaneo de puertos
nmap -sn 172.30.0.0/24
```

**Qué observas:** una línea `Nmap scan report for <ip>` + `Host is up` por cada IP viva,
y al final `Nmap done: 256 IP addresses (N hosts up)`. Ese `N` es el corazón de M01.

> `-sn` significa "**s**can, **n**o port scan". (Antes se llamaba `-sP`, "ping scan".)

---

## 2. Las técnicas, una por una

### 2.1 `-PR` — ARP ping (el rey de la LAN)

Dentro del **mismo segmento de capa 2** (como nuestra red Docker `recon_net`), nmap usa
**ARP** por defecto. ARP pregunta "¿quién tiene la IP X?" y la máquina dueña responde con
su MAC. Es **rápido, fiable y no se puede bloquear con un firewall de capa 3**: si la
máquina está en la LAN, contesta.

```bash
# Forzar explícitamente ARP ping (en la LAN ya es el comportamiento por defecto)
nmap -sn -PR 172.30.0.0/24
```

**Por qué importa:** como tu Kali (172.30.0.1, gateway del bridge) está en la **misma subred** que todos
los objetivos, ARP los ve a todos aunque tengan firewalls que filtren ICMP o TCP. Por eso
M01 es tan determinista en este lab.

### 2.2 `-PS` / `-PA` — TCP SYN / ACK ping

Cuando no estás en la misma LAN (hay routers de por medio), ARP no llega y necesitas
sondas de capas superiores. Las TCP son las más útiles:

- **`-PS<puertos>`** envía un **SYN**. Si el host está vivo, responde **SYN/ACK** (puerto
  abierto) o **RST** (puerto cerrado): en ambos casos, **está vivo**.
- **`-PA<puertos>`** envía un **ACK**. Un host vivo responde **RST** (porque ese ACK no
  pertenece a ninguna conexión). Útil para pasar firewalls que solo filtran SYN.

```bash
# SYN ping a puertos típicos (si no indicas puertos, usa 80 por defecto)
nmap -sn -PS22,80,443 172.30.0.21

# ACK ping
nmap -sn -PA80 172.30.0.21
```

**Qué observas:** "Host is up" si llega cualquier respuesta TCP. La belleza es que no te
importa el *estado* del puerto, solo que el host **contestó algo**.

### 2.3 `-PE` / `-PP` — ICMP echo / timestamp ping

Las sondas ICMP clásicas:

- **`-PE`** → ICMP **Echo Request** (el "ping de toda la vida"). Vivo si responde Echo
  Reply.
- **`-PP`** → ICMP **Timestamp Request**. Alternativa cuando el Echo está filtrado pero el
  timestamp no.

```bash
# ICMP echo ping
nmap -sn -PE 172.30.0.25

# ICMP timestamp ping (a veces pasa donde el echo no)
nmap -sn -PP 172.30.0.25
```

**Por qué hay varias:** muchos firewalls bloquean Echo pero olvidan Timestamp. Probar
varias sondas reduce falsos negativos ("host vivo que parece muerto").

### 2.4 `-Pn` — "trátalo como vivo, no preguntes"

`-Pn` **desactiva el descubrimiento**: nmap asume que el host está vivo y pasa directo a
escanear puertos. Se usa cuando *sabes* que está ahí pero bloquea todas las sondas de
discovery (te ahorra falsos "host seems down").

```bash
# No descubrir; ir directo a puertos (útil contra hosts que filtran todo el ping)
nmap -Pn 172.30.0.23
```

> **Cuidado:** `-Pn` es más lento y ruidoso si lo lanzas contra un rango grande, porque
> escanea puertos de IPs que quizá no existen. Úsalo con criterio.

### 2.5 Listas de objetivos (`-iL`) y formatos de rango

Puedes escanear exactamente tu **alcance** desde un fichero, o usar notación de rango/CIDR:

```bash
# Desde un fichero (una IP por línea) — respeta tu scope al pie de la letra
nmap -sn -iL /tmp/scope.txt

# Rango con guion
nmap -sn 172.30.0.21-27

# Lista separada por comas dentro del último octeto
nmap -sn 172.30.0.21,22,23

# CIDR (toda la subred)
nmap -sn 172.30.0.0/24

# Solo LISTAR objetivos sin enviar ni una sonda (-sL, "list scan"): útil para revisar
nmap -sL 172.30.0.21-27
```

> `-sL` no toca la red: solo te muestra qué IPs *resolvería* el rango. Perfecto para
> verificar que tu scope es el que crees antes de disparar.

---

## 3. El matiz del conteo: gateway, red y broadcast

Aquí está la lección clave de M01. Cuando barres **172.30.0.0/24**, no todas las
direcciones son "hosts" en el sentido útil:

```
172.30.0.0    → dirección de RED       (no es un host; identifica la subred)
172.30.0.1    → GATEWAY                 (existe y responde, pero NO es objetivo del lab)
172.30.0.5    → scoreboard             (vivo; infraestructura, no "presa")
172.30.0.1    → tu Kali / gateway (TÚ MISMO)   (cuéntalo o no, según criterio)
172.30.0.21   → alpha    ┐
172.30.0.22   → bravo    │
172.30.0.23   → charlie  │
172.30.0.24   → delta    ├─ los 7 OBJETIVOS del lab (172.30.0.21–.27)
172.30.0.25   → echo     │
172.30.0.26   → foxtrot  │
172.30.0.27   → hotel    ┘
172.30.0.255  → dirección de BROADCAST  (no es un host)
```

Tres sutilezas que todo profesional debe interiorizar:

1. **Dirección de red (`.0`) y broadcast (`.255`)** nunca son hosts asignables: son
   direcciones especiales de la subred. No las cuentes.
2. **El gateway (`.1`)** está vivo y `-sn` lo reportará, **pero no es un objetivo** del
   lab. Que algo responda no significa que sea parte de tu alcance.
3. **Tú mismo (`attacker`, .10)** apareces en el barrido. Según cómo cuentes, te incluyes
   o no. Un operador suele contar "los demás", no a sí mismo.

> **Por eso M01 tiene un matiz de conteo.** Dependiendo de si incluyes o no el gateway, el
> número "correcto" cambia en uno. El scoreboard está preparado para esa ambigüedad y
> **acepta el conteo razonado** (con y sin gateway). La gracia del ejercicio no es
> adivinar un número, sino **entender por qué** ese número es el que es.

---

## 4. `hping3` e ICMP: descubrimiento a mano

`nmap -sn` es cómodo, pero a veces quieres **fabricar la sonda tú mismo** para entender
qué viaja por el cable. `hping3` te deja enviar paquetes uno a uno.

```bash
# Un "ping" ICMP artesanal: 1 paquete Echo Request a alpha
hping3 --icmp -c 1 172.30.0.21
```

**Qué observas:** una línea `len=... ip=172.30.0.21 ... icmp_seq=0` si el host responde
con Echo Reply → está vivo. Fíjate en el campo **`ttl=`**: te adelanta información de SO
(lo explotarás en [08 · OS/TTL](06-version-os-detection.md) y
[10 · hping3](08-hping3.md)).

También puedes "descubrir" con un SYN a un puerto concreto (TCP ping manual):

```bash
# SYN al puerto 80 de alpha: si responde SA (SYN/ACK), el host vive y el puerto está abierto
hping3 -S -p 80 -c 1 172.30.0.21
```

**Qué observas:** `flags=SA` (SYN/ACK) → puerto abierto y host vivo; `flags=RA` (RST/ACK)
→ host vivo pero puerto cerrado; **sin respuesta** → filtrado o host caído. Esta lógica es
exactamente la de `-PS` de nmap, pero viéndola "en crudo".

> El detalle de las flags TCP (`S`, `SA`, `RA`, `R`…) y por qué cada una significa lo que
> significa está en [03 · Cabeceras TCP](03-tcp-headers.md).

---

## 5. Ejercicio guiado · M01 · Primer Contacto

> **Tipo:** `answer` · **Objetivo:** contar los hosts vivos de la subred del lab.
> **Puntos:** 50. Tu primera medalla `first-blood` te espera si es tu primer reto. 🎖️

### Paso 1 — Prepárate (en tu propia Kali, nativo)

No necesitas ningún contenedor: escaneas directamente desde tu host. (Opcional, una vez:)

```bash
sudo ./recon-hosts.sh     # registra alpha..hotel en /etc/hosts; el barrido funciona por IP igualmente
```

### Paso 2 — Lanza el barrido de descubrimiento

```bash
nmap -sn 172.30.0.0/24
```

Observa la última línea: `Nmap done: 256 IP addresses (N hosts up) scanned in ...`.
Ese `N` es tu materia prima.

### Paso 3 — Razona el conteo (lo importante)

No entregues `N` a ciegas. Repásalo con lo que aprendiste en §3:

- ¿Cuántas de las direcciones reportadas son **objetivos del lab** (172.30.0.21–.27)?
- ¿Aparece el **scoreboard** (.5)? (Sí: es infraestructura viva.)
- ¿Aparece el **gateway** (.1)? Es **tu propia Kali** (escaneas desde el host): ¿lo cuentas?
- Si levantaste la estación **opcional** `attacker` (.10), también aparecerá.

Recompón el número **explicando cada dirección**. Una forma limpia de aislar solo lo que
te interesa:

```bash
# Ver solo las líneas "Host is up" y contar a mano
nmap -sn 172.30.0.0/24 | grep -i "report\|host is up"

# O contar los hosts vivos directamente
nmap -sn 172.30.0.0/24 -oG - | grep -c "Status: Up"
```

### Paso 4 — Verifica con ARP (confianza extra)

Como estás en la misma LAN, el ARP ping no miente:

```bash
sudo nmap -sn -PR 172.30.0.0/24      # ARP ping: requiere privilegios (raw)
```

¿Coincide con tu conteo razonado? Si sí, tienes tu respuesta.

### Paso 5 — Entrega en el scoreboard

Ve a <http://localhost:8080>, abre **M01 · Primer Contacto** y entrega tu número.

> **Pista (sin la respuesta):** la cuenta "limpia" es **scoreboard + los 7 objetivos**.
> Si además incluyes el gateway, sube en uno. El scoreboard **acepta ambas
> interpretaciones razonadas**, así que lo que de verdad puntúa es que sepas *justificar*
> tu número. No incluyas red/broadcast (no son hosts) ni te cuentes a ti mismo.

---

## 6. Errores comunes (y cómo evitarlos)

| Error | Síntoma | Solución |
|-------|---------|----------|
| Contar `.0` o `.255` | Número demasiado alto | Son red/broadcast, no hosts |
| Olvidar el scoreboard | Número demasiado bajo | `.5` está vivo y cuenta |
| Confundir gateway con objetivo | Mezclas scope | `.1` responde pero **no es presa** |
| Usar `-Pn` para "descubrir" | No descubre nada (lo desactiva) | `-Pn` *asume* vivo; para contar usa `-sn` |
| Fiarte solo de ICMP | Falsos "host down" | En LAN, ARP (`-PR`) es la verdad |

---

## 7. Resumen

- **`-sn`** descubre sin escanear puertos; en LAN usa **ARP** (`-PR`), imbatible.
- **`-PS/-PA`** (TCP) y **`-PE/-PP`** (ICMP) son sondas para cuando ARP no llega.
- **`-Pn`** desactiva el descubrimiento (asume vivo); **`-sL`** solo lista, sin tocar la
  red.
- El **conteo** correcto exige distinguir host real de gateway, red, broadcast y de ti
  mismo: ese es el corazón de **M01**.
- `hping3 --icmp` y `hping3 -S` te enseñan el descubrimiento "a mano".

> Siguiente parada: entiende **cómo** una sonda TCP provoca SYN/ACK o RST en
> [03 · Anatomía de las cabeceras TCP/IP](03-tcp-headers.md). Es la base de todo lo que
> viene.
