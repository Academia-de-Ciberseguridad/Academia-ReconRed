# 01 · Metodología profesional de reconocimiento

> **El reconocimiento no es "lanzar nmap a lo loco".** Es un proceso ordenado que un
> profesional repite con disciplina: definir el alcance, descubrir qué hay vivo,
> enumerar puertos, identificar servicios y versiones, deducir el sistema operativo y
> —cuando hace falta— evadir defensas de forma responsable, **documentándolo todo**.
> En este documento conectamos cada fase con las misiones del scoreboard.

---

## 0. El mapa mental: las fases del recon

```
   [0] Alcance / Autorización
            │
            ▼
   [1] Descubrimiento de hosts  ───────────►  M01  (¿qué está vivo?)
            │
            ▼
   [2] Enumeración de puertos   ───────────►  M02, M05, M06, M07
            │
            ▼
   [3] Identificación de servicios/versión ─►  M03, M04, M09
            │
            ▼
   [4] Detección de SO          ───────────►  M08
            │
            ▼
   [5] Evasión responsable      ───────────►  M11
            │
            ▼
   [6] Documentación / reporte  ───────────►  M12 (mapa total)
```

Cada flecha es una pregunta concreta que le haces a la red. El arte está en **elegir la
pregunta correcta** y **leer bien la respuesta**.

---

## Fase 0 · Alcance y autorización

> **Antes de enviar un solo paquete:** ¿tengo permiso, y sobre qué exactamente?

En el mundo real, esta fase es la que te mantiene fuera de la cárcel. Un profesional:

- Obtiene **autorización por escrito** (contrato, *Rules of Engagement*).
- Define el **alcance** (scope): rangos de IP, dominios, ventanas horarias, técnicas
  permitidas y prohibidas.
- Acuerda **qué NO tocar** (sistemas críticos, terceros, DoS…).

### En el lab

El alcance está fijado por el [LAB-SPEC](../LAB-SPEC.md): tus objetivos legítimos son
**172.30.0.21–172.30.0.27** (`alpha`…`hotel`). El `scoreboard` (.5) y tu propia estación
`attacker` (.10) **no son presas**. El gateway (.1) tampoco.

```bash
# Tu alcance, documentado como lista de objetivos:
cat > /tmp/scope.txt <<'EOF'
172.30.0.21
172.30.0.22
172.30.0.23
172.30.0.24
172.30.0.25
172.30.0.26
172.30.0.27
EOF
```

> Más adelante usarás `nmap -iL /tmp/scope.txt` para escanear exactamente tu alcance, ni
> una IP de más. Respetar el scope es parte de la profesionalidad.

---

## Fase 1 · Descubrimiento de hosts

> **Pregunta:** de todo el rango, ¿qué direcciones están **vivas**?

No tiene sentido escanear 254 IPs si solo 8 responden. El descubrimiento (host
discovery / *ping sweep*) reduce el universo a lo que existe.

```bash
# Barrido de descubrimiento (sin escaneo de puertos) en toda la subred
nmap -sn 172.30.0.0/24
```

**Qué observas:** una lista de "Host is up" por cada IP que responde. En una LAN, nmap
prefiere **ARP** (`-PR`), que es rápido e infalible dentro del mismo segmento.

> **Misión asociada:** **M01 · Primer Contacto** (`answer`). Cuenta los hosts vivos.
> Ojo al matiz del gateway y de no contarte a ti mismo: lo explica en detalle
> [02 · Host Discovery](02-host-discovery.md). El scoreboard acepta el conteo correcto
> con su matiz documentado.

---

## Fase 2 · Enumeración de puertos

> **Pregunta:** en cada host vivo, ¿qué **puertos** están abiertos, cerrados o
> filtrados?

Aquí empieza el verdadero mapeo. Los tres estados que más importan:

- **open** — alguien escucha y responde.
- **closed** — nadie escucha, pero el host responde "puerto cerrado" (RST).
- **filtered** — un firewall se traga el paquete; no hay respuesta clara.

```bash
# Escaneo TCP connect (no requiere privilegios; completa el handshake)
nmap -sT 172.30.0.21

# Escaneo SYN ("half-open", más sigiloso y rápido; requiere NET_RAW, que ya tienes)
nmap -sS 172.30.0.21
```

> **Misiones asociadas:**
> - **M02 · Puertas Abiertas** — encuentra los puertos web de `alpha` y su flag.
> - **M05 · Estados Cuánticos** y **M06 · Cortafuegos al Desnudo** — distingue
>   open/closed/filtered en `charlie`.
> - **M07 · Aguja en el Pajar** — separa el puerto real de 50 decoys en `delta`.

La diferencia entre estados (y cómo un firewall los produce) se trata en
[06 · Estados de puerto y firewalls](05-estados-de-puertos.md). La base teórica de por
qué un SYN provoca SYN/ACK o RST está en
[03 · Cabeceras TCP](03-tcp-headers.md).

---

## Fase 3 · Identificación de servicios y versión

> **Pregunta:** ese puerto abierto, ¿**qué servicio** es y de **qué versión**?

Un puerto abierto es un comienzo; lo valioso es saber *qué* corre ahí (y si tiene
vulnerabilidades conocidas).

```bash
# Detección de versión: nmap interroga el servicio y compara banners/firmas
nmap -sV 172.30.0.21

# Scripts NSE para enumeración (ej. cabeceras HTTP, info de servicios)
nmap -sV --script=banner 172.30.0.22
```

A veces hay que **interactuar a mano** con el servicio (un cliente real dice más que un
escáner):

```bash
# Hablar con redis directamente (bravo)
redis-cli -h 172.30.0.22 PING
```

> **Misiones asociadas:**
> - **M03 · Identidades** (`answer`) — qué servicio sirve `alpha:80`.
> - **M04 · El Tesoro de Redis** (`flag`) — interactúa con redis en `bravo` y léete una
>   clave.
> - **M09 · Territorio UDP** (`flag`) — enumera un registro DNS TXT en `foxtrot`.

Detalle en [05 · Detección de versión](06-version-os-detection.md) y
[09 · UDP](09-evasion-firewall.md).

---

## Fase 4 · Detección de sistema operativo

> **Pregunta:** ¿qué **SO** corre el host?

Pistas: el **TTL** inicial (Linux ~64, Windows ~128, equipos de red ~255), el tamaño de
ventana TCP, el orden de opciones TCP, y los banners de servicios típicos de cada
plataforma.

```bash
# Detección de SO de nmap (requiere privilegios; usa firmas de pila TCP/IP)
nmap -O 172.30.0.25

# Inspección manual del TTL con una sonda (lo verás en 08 y 10)
ping -c1 172.30.0.25
```

> **Misión asociada:** **M08 · Huella Digital** (`answer`). En `echo`, el TTL y los
> banners sugieren un SO concreto. **Cuidado:** en contenedores la detección de SO tiene
> límites (todos comparten kernel Linux); por eso `echo` *fuerza* su TTL y expone
> banners "Windows-like" para que aprendas a **interpretar pistas**, no a fiarte ciegamente
> de una herramienta. Lo explica [08 · OS/TTL](06-version-os-detection.md).

---

## Fase 5 · Evasión responsable

> **Pregunta:** si un firewall me bloquea, ¿cómo **atravieso** sus reglas… de forma
> ética y documentada?

Las defensas se pueden sortear con técnicas legítimas de auditoría: **puerto de origen
"de confianza"** (`--source-port 53`/`-g 53`), **fragmentación** (`-f`), ajustes de
*timing* (`-T`), o **decoys** (`-D`). Un profesional las usa para *probar* la eficacia de
las defensas, **no** para hacer daño, y deja constancia de cada técnica empleada.

```bash
# Usar puerto de origen 53 (DNS) para intentar pasar reglas mal configuradas
nmap -sS -g 53 172.30.0.23

# Fragmentar paquetes para evadir inspección simple
nmap -sS -f 172.30.0.23
```

> **Misión asociada:** **M11 · Operación Sigilo** (`answer`). Premia haber usado un
> puerto de origen "mágico" o fragmentación contra `charlie`/`hotel`. El detalle (y las
> respuestas que el scoreboard acepta) está en
> [09 · UDP y evasión](09-evasion-firewall.md). **Evasión ≠ travesura:** solo dentro de tu
> alcance autorizado.

---

## Fase 6 · Documentación y reporte

> **Pregunta:** ¿puedo **reconstruir y comunicar** todo lo que descubrí?

El recon no termina cuando encuentras un puerto: termina cuando tienes un **mapa
reproducible**. Un buen operador:

- Guarda la salida de cada escaneo (`-oA` exporta a los 3 formatos a la vez).
- Anota host, puerto, servicio, versión, estado y evidencia.
- Construye un **mapa total** de la red.

```bash
# Exportar resultados a normal + grepable + XML de una sola vez
nmap -sV -oA /tmp/recon-alpha 172.30.0.21

# Escanear todo el alcance desde la lista de objetivos
nmap -sV -iL /tmp/scope.txt -oA /tmp/recon-todos
```

> **Misión asociada:** **M12 · BOSS · Mapa Total** (`flag`). Es la recompensa final: el
> scoreboard la desbloquea cuando completas el grueso de las misiones de mapeo
> (M02, M04, M05, M07, M08, M09, M10). Tu documentación es lo que te lleva hasta aquí.

---

## Tabla resumen: fase ↔ misión ↔ documento

| Fase | Misión(es)                        | Documento de referencia                       |
|------|-----------------------------------|-----------------------------------------------|
| 0 Alcance        | (todas)               | Este documento · LAB-SPEC                     |
| 1 Descubrimiento | **M01**               | [02 · Host Discovery](02-host-discovery.md)   |
| 2 Puertos        | **M02, M05, M06, M07**| [04](04-tipos-de-escaneo.md), [06](05-estados-de-puertos.md), [07](04-tipos-de-escaneo.md) |
| 3 Servicios/ver. | **M03, M04, M09**     | [05](06-version-os-detection.md), [09](09-evasion-firewall.md) |
| 4 SO             | **M08**               | [08 · OS/TTL](06-version-os-detection.md)         |
| 5 Evasión        | **M11**               | [09 · UDP y evasión](09-evasion-firewall.md)       |
| 6 Documentación  | **M12 (boss)**        | Este documento · Cheatsheet                   |

---

## Principios del buen operador

1. **Mínimo ruido necesario.** Empieza suave (discovery), escala solo si hace falta.
2. **Una pregunta por escaneo.** Sabe *qué* estás midiendo y *por qué*.
3. **Verifica, no asumas.** Si nmap dice "filtered", confírmalo con otra técnica.
4. **Respeta el alcance.** Ni una IP fuera del scope autorizado.
5. **Documenta en caliente.** El reporte se escribe mientras escaneas, no después.

> Con esta metodología en la cabeza, sigue a [02 · Host Discovery](02-host-discovery.md)
> y completa tu **Primer Contacto** (M01).
