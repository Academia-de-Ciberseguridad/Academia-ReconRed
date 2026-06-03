# /labs — tu cuaderno de campo

Esta carpeta es tuya. Guarda aquí tus notas y los volcados de tus escaneos
mientras avanzas en **Operación Red Recon**. Persiste mientras viva el
contenedor `attacker`.

## Cómo guardar un escaneo

```bash
# Texto normal
nmap -sV 172.30.0.21 | tee /labs/alpha-sV.txt

# Todos los formatos de nmap a la vez (normal, grepable, XML)
nmap -sV -oA /labs/alpha 172.30.0.21
```

## Sugerencia de organización

```
/labs/
  notas.md          # tus apuntes, flags encontradas, hipótesis
  alpha-sV.txt      # un fichero por objetivo/fase
  delta-allports.txt
  ...
```

## Recordatorios

- Objetivos y pistas:  `recon-targets`
- Chuleta de comandos: `recon-help`
- Barrido rápido:      `sweep`  (nmap -sn 172.30.0.0/24)
- Scoreboard:          http://localhost:8080  (host)
                       http://172.30.0.5:8000 (interno al lab)

Las flags tienen el formato `RECON{...}`. Cuando encuentres una, anótala aquí
y envíala al scoreboard.

> Laboratorio aislado y de uso educativo. No lo expongas a Internet ni uses
> estas técnicas fuera de entornos autorizados.
