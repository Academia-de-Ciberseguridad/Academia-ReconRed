# 07 · El motor NSE — Nmap como plataforma de scripting

> **Operación Red Recon** · Módulo NSE, hping3 y evasión (parte C)
> **Nativo:** ejecutas desde tu Kali contra 172.30.0.21–.27 (SYN/UDP/OS y `hping3` con `sudo`).
> Objetivos de práctica: **alpha** (`172.30.0.21`, `http-*`) y
> **foxtrot** (`172.30.0.26`, `dns-*` / `snmp-*`).
> Misiones conectadas: refuerza **M02** (web), **M03** (versión) y **M09** (DNS/UDP).

---

## Briefing

Nmap no es solo un escáner de puertos: es una **plataforma de automatización de
reconocimiento**. Su corazón programable se llama **NSE** (*Nmap Scripting Engine*),
y está escrito en **Lua**. Con NSE, una vez que sabes *qué* puerto está abierto,
puedes pedirle a Nmap que **interrogue** a ese servicio: que lea su banner, saque el
título de una web, enumere los algoritmos de SSH, consulte una zona DNS o sondee
SNMP… todo en la misma pasada.

En este documento pasas de "escanear puertos" a "**extraer inteligencia**". El salto
de operador novato a operador competente es, en buena parte, saber **qué script
lanzar y cómo leer su salida**.

> 🎮 **Recompensa del módulo:** dominar `--script` te da atajos directos a las pistas
> de **alpha** (cabeceras y título HTTP) y **foxtrot** (registro TXT de DNS).

---

## 1) ¿Qué es NSE y por qué existe?

Imagina que tienes 20 hosts y, para cada web, quieres el título de la página, las
cabeceras HTTP y comprobar si hay un `robots.txt`. Hacerlo a mano con `curl` host por
host es tedioso. NSE lo **automatiza y paraleliza**: cada script es un pequeño
programa Lua que Nmap ejecuta contra los objetivos que cumplan una condición (por
ejemplo, "el puerto 80 está abierto").

Cada script declara:

- **Categorías** a las que pertenece (`safe`, `default`, `discovery`, `version`,
  `vuln`…).
- Una **regla** (*rule*) que decide si debe ejecutarse contra un host/puerto.
- La **acción**: qué hace y qué texto devuelve.

Los scripts viven (en Kali / la imagen del lab) normalmente en:

```bash
# ¿Dónde están los .nse? (suele ser /usr/share/nmap/scripts)
ls /usr/share/nmap/scripts/ | head
ls /usr/share/nmap/scripts/ | wc -l    # ¡cientos de scripts disponibles!
```

---

## 2) Las categorías de NSE (tu mapa mental)

Los scripts se agrupan en **categorías**. Conocerlas te deja lanzar "familias enteras"
sin recordar nombres exactos.

| Categoría | Qué hace | ¿Ruidosa? |
|---|---|---|
| **`safe`** | No diseñada para tirar servicios ni explotar; solo recoge información | No |
| **`default`** | Lo que corre con `-sC` / `-A`: equilibrio útil entre valor y seguridad | Baja |
| **`discovery`** | Descubre más sobre la red/servicio (rutas, hosts, recursos) | Media |
| **`version`** | Extiende `-sV` con sondas avanzadas de versión | Baja |
| **`auth`** | Tratan con credenciales / autenticación (sin fuerza bruta) | Media |
| **`brute`** | **Fuerza bruta** de credenciales | **Alta** |
| **`vuln`** | Comprueba **vulnerabilidades** conocidas | Media/Alta |
| **`exploit`** | Intenta **explotar** activamente | **Alta** |
| **`dos`** | Pruebas de **denegación de servicio** | **¡Peligrosa!** |
| **`intrusive`** | Lo contrario de `safe`: puede afectar al objetivo | Alta |
| **`malware`** | Detecta backdoors / hosts comprometidos | Baja |
| **`fuzzer`** | Envía datos malformados (fuzzing) | Alta |

> ⚠️ **Regla del lab:** en "Operación Red Recon" usamos categorías **`safe`,
> `default`, `discovery`, `version`** y scripts puntuales de `vuln` con criterio.
> `brute`, `exploit`, `dos` y `fuzzer` **no** son necesarios para ninguna misión y
> pueden estresar a los contenedores. Recon ≠ explotación.

---

## 3) Cómo seleccionar scripts: `--script`

La opción `--script` acepta **cuatro formas** de elegir qué ejecutar:

```bash
# (a) Por NOMBRE exacto de un script
nmap --script http-title -p 80 172.30.0.21

# (b) Por CATEGORÍA (familia entera)
nmap --script safe -p 80 172.30.0.21

# (c) Por COMODÍN (wildcard): todos los http-*, todos los dns-* ...
nmap --script "http-*" -p 80 172.30.0.21

# (d) Por EXPRESIÓN booleana (and / or / not)
nmap --script "default and safe" -p 80 172.30.0.21
nmap --script "(discovery or version) and not intrusive" 172.30.0.26
```

Atajos cómodos que ya conoces de otros documentos:

- **`-sC`** = `--script default` (los scripts por defecto).
- **`-A`** = agresivo: combina `-sV` + `-O` + `-sC` + traceroute en un solo comando.

```bash
# Pasada agresiva contra alpha (versión + SO + scripts default + traceroute)
nmap -A -p 22,80,8080 172.30.0.21
```

---

## 4) Documentación viva: `--script-help`

Antes de lanzar un script a ciegas, **léelo**. NSE trae su propia ayuda:

```bash
# ¿Qué hace exactamente este script y qué argumentos acepta?
nmap --script-help http-headers
nmap --script-help "snmp-*"
nmap --script-help dns-zone-transfer
```

`--script-help` imprime la **descripción**, las **categorías** del script y, muy
importante, los **argumentos** (`--script-args`) que admite. Esto es oro: te dice cómo
afinar el script sin abrir el `.nse`.

> **Hábito de operador:** `--script-help` **antes** de `--script`. Saber qué hace una
> herramienta antes de dispararla es la diferencia entre un profesional y un script
> kiddie. En el lab no hay riesgo, pero el hábito te acompaña al mundo real.

### Pasar argumentos a un script: `--script-args`

```bash
# Ejemplo de sintaxis (clave=valor, separadas por coma)
nmap --script http-headers --script-args http-headers.path=/robots.txt -p 80 172.30.0.21
```

---

## 5) Scripts útiles para el lab (catálogo comentado)

### 5.1 Banner genérico

```bash
# Lee el banner de CUALQUIER servicio de texto (SSH, redis, banners de portsrv...)
nmap --script banner -p 22,80 172.30.0.21
```

Qué observas y por qué: `banner` abre la conexión y vuelca los primeros bytes que el
servicio envía. En `22` verás `SSH-2.0-OpenSSH_...` (SSH se presenta solo); es la
versión "NSE" del *banner grabbing* manual que hiciste con `nc` en el doc 06.

### 5.2 Familia `http-*` (práctica contra **alpha**)

| Script | Qué extrae |
|---|---|
| **`http-title`** | El `<title>` de la página → identifica rápido qué hay |
| **`http-headers`** | **Todas** las cabeceras de respuesta (incluida `Server:` y custom) |
| **`http-methods`** | Métodos HTTP permitidos (GET, POST, OPTIONS…) |
| **`http-robots.txt`** | Lee y parsea `/robots.txt` (¡rutas "ocultas"!) |
| **`http-enum`** | Enumera ficheros/directorios comunes |

```bash
# Título + cabeceras + robots de alpha en una sola pasada
nmap --script "http-title,http-headers,http-robots.txt" -p 80,8080 172.30.0.21
```

**Qué observas y por qué en alpha:**

- `http-headers` lista la cabecera `Server: nginx/...` (confirma **M03 = nginx**) y la
  cabecera **personalizada `X-Recon-Flag`** que el lab añade adrede.
- `http-robots.txt` revela el contenido de `/robots.txt`, donde alpha esconde la pista
  de **M02**.
- `http-title` te da el título del vhost "panel" en `8080`, una pista de la versión.

> 🔒 Como en toda la teoría: **no transcribimos el flag aquí**. NSE te lo pondrá
> delante en la salida; el valor exacto lo lees tú (o lo confirmas en el solucionario).

### 5.3 SSH: `ssh2-enum-algos`

```bash
# Algoritmos de cifrado/MAC/KEX que ofrece el SSH real de alpha
nmap --script ssh2-enum-algos -p 22 172.30.0.21
```

Qué observas y por qué: lista los algoritmos de intercambio de claves, cifrado, MAC y
compresión que el servidor soporta. En auditorías reales sirve para detectar
algoritmos **débiles/obsoletos**. Aquí es una práctica limpia contra un OpenSSH real.

> Relacionados: `ssh-hostkey` (huellas de las claves de host), `ssh-auth-methods`
> (métodos de autenticación ofrecidos).

### 5.4 Familia `dns-*` (práctica contra **foxtrot**)

foxtrot corre un **dnsmasq real** con la zona `recon.lab`. Los scripts `dns-*` son tu
camino "automatizado" hacia **M09**.

| Script | Qué hace |
|---|---|
| **`dns-zone-transfer`** | Intenta una **transferencia de zona (AXFR)**: si el server lo permite, vuelca TODOS los registros |
| **`dns-nsid`** | Pide el identificador del servidor DNS |
| **`dns-recursion`** | Comprueba si el resolver permite recursión |
| **`dns-srv-enum`** | Enumera registros SRV de servicios comunes |

```bash
# ¿Permite foxtrot una transferencia de zona de recon.lab?
nmap --script dns-zone-transfer --script-args dns-zone-transfer.domain=recon.lab \
     -p 53 172.30.0.26
```

**Qué observas y por qué:** si la zona permite AXFR, verás un volcado con **todos** los
registros de `recon.lab`, incluido el **TXT** que contiene la pista de **M09**. Si no
lo permite, tendrás que consultar el TXT directamente (lo verás en el doc del módulo
UDP/DNS y abajo en el laboratorio guiado, con `dig`).

> 💡 La consulta directa del TXT no es NSE, pero es el camino canónico de M09:
> ```bash
> dig @172.30.0.26 flag.recon.lab TXT +short
> ```
> El `+short` te deja **solo** el valor del registro: ahí vive la pista de M09.

### 5.5 Familia `snmp-*` (práctica contra **foxtrot**, UDP/161)

foxtrot expone un banner **SNMP-like** en `161/udp` (comunidad `public`). Los
`snmp-*` enumeran información que SNMP suele filtrar.

| Script | Qué intenta enumerar |
|---|---|
| **`snmp-info`** | Información básica del agente SNMP |
| **`snmp-sysdescr`** | La descripción del sistema (`sysDescr`) |
| **`snmp-interfaces`** | Interfaces de red |
| **`snmp-processes`** | Procesos en ejecución |
| **`snmp-brute`** | (categoría `brute`) fuerza la *community string* — **no necesario en el lab** |

```bash
# OJO: SNMP es UDP -> hace falta -sU para que el puerto se considere "abierto"
nmap -sU --script "snmp-sysdescr,snmp-info" -p 161 172.30.0.26
```

**Qué observas y por qué:** como SNMP viaja sobre **UDP**, debes combinar los scripts
con **`-sU`**; si lanzas `snmp-*` sin `-sU`, Nmap no tendrá un puerto UDP "abierto"
sobre el que ejecutarlos. El banner del lab imita la comunidad `public` para que la
enumeración devuelva algo didáctico.

---

## 6) Cómo leer la salida de NSE

La salida de un script aparece **indentada bajo la línea del puerto** al que pertenece,
con el **nombre del script** como prefijo:

```
PORT   STATE SERVICE
80/tcp open  http
| http-title: Panel de administración - Recon Lab
| http-headers:
|   Server: nginx/1.24.0
|   X-Recon-Flag: RECON{...}        <- (lo lees tú; aquí no se transcribe)
|_  Date: ...
```

Claves para interpretarla:

- **`|`** marca líneas de salida del script; **`|_`** marca la **última** línea de ese
  script.
- El **prefijo** (`http-title:`, `http-headers:`) te dice **qué script** produjo cada
  bloque: útil cuando lanzas varios a la vez.
- Si un script **no** devuelve nada, simplemente **no aparece** (no es un error).
- Los scripts a nivel de **host** (no de puerto) salen arriba, bajo la línea del host.

> Truco de evidencia: guarda siempre la salida con `-oN`/`-oA` para tu informe:
> ```bash
> nmap --script "http-title,http-headers" -p 80,8080 172.30.0.21 -oN /labs/alpha-nse.txt
> ```

---

## 7) Laboratorio guiado (cópialo entero)

```bash
# === alpha: inteligencia HTTP (apoya M02 y M03) ===
# 1) ¿Qué hace cada script antes de lanzarlo?
nmap --script-help http-headers,http-title

# 2) Título + cabeceras + robots de alpha (80 y 8080)
nmap --script "http-title,http-headers,http-robots.txt" -p 80,8080 172.30.0.21 \
     -oN /labs/alpha-http-nse.txt

# 3) SSH: algoritmos ofrecidos por el OpenSSH real
nmap --script ssh2-enum-algos -p 22 172.30.0.21 -oN /labs/alpha-ssh-nse.txt

# === foxtrot: DNS y SNMP (apoya M09) ===
# 4) ¿Permite transferencia de zona de recon.lab?
nmap --script dns-zone-transfer \
     --script-args dns-zone-transfer.domain=recon.lab \
     -p 53 172.30.0.26 -oN /labs/foxtrot-dns-nse.txt

# 5) Camino directo al TXT (canónico para M09)
dig @172.30.0.26 flag.recon.lab TXT +short

# 6) SNMP sobre UDP (recuerda -sU)
nmap -sU --script "snmp-sysdescr,snmp-info" -p 161 172.30.0.26 \
     -oN /labs/foxtrot-snmp-nse.txt
```

**Checklist del operador (✔ módulo completado):**

- [ ] Sé qué es **NSE** y dónde viven los scripts (`/usr/share/nmap/scripts`).
- [ ] Conozco las **categorías** (`safe/default/discovery/version/vuln…`) y cuáles
      **no** usamos en el lab.
- [ ] Sé seleccionar scripts por **nombre, categoría, comodín y expresión booleana**.
- [ ] Uso **`--script-help`** *antes* de lanzar un script.
- [ ] Sé leer la salida indentada (`|`, `|_`, prefijo del script).
- [ ] He sacado **cabeceras/título** de alpha (`http-*`) y consultado **DNS/SNMP** de
      foxtrot (`dns-*`, `snmp-*`, recordando `-sU`).

---

## Cierre

NSE convierte a Nmap de "linterna que busca puertas" en "**equipo de interrogadores**"
que, una vez abierta la puerta, te cuenta qué hay dentro. Con `http-*`, `dns-*` y
`snmp-*` ya tienes atajos directos a las pistas de **alpha** y **foxtrot**.

A continuación bajamos al **nivel del paquete crudo** con `hping3`
([08 · hping3](08-hping3.md)): allí dejarás de pedirle a Nmap que hable por ti y
**encenderás las flags TCP tú mismo**.

> *Nmap escanea; NSE pregunta. El operador que sabe preguntar, gana.* 🛰️
