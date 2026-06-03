#!/usr/bin/env python3
"""
portsrv.py — Simulador multipuerto TCP/UDP para "Operación Red Recon".

Solo biblioteca estándar. Abre los puertos definidos en un fichero JSON
(env PORTSRV_CONFIG, por defecto /etc/portsrv.json) y responde con banners,
respuestas HTTP o eco, de forma que herramientas como nmap -sV puedan
clasificarlos de manera DIDACTICA (no es un servicio real).

Formato de configuracion:
{
  "default_close_ms": 1500,          // ms antes de cerrar una conexion banner
  "ports": [
    {"port": 22, "mode": "banner", "banner": "SSH-2.0-OpenSSH_8.9p1\r\n"},
    {"port": 80, "mode": "http",
       "http_status": "200 OK",
       "http_headers": {"Server": "nginx/1.24.0", "X-Recon-Flag": "RECON{..}"},
       "http_body": "<html>hola</html>"},
    {"port": 161, "proto": "udp", "mode": "banner", "banner": "public\n"},
    {"port_range": [9000, 9049], "mode": "banner", "banner": "decoy ready\r\n"}
  ]
}

Reglas:
- Una entrada con "port" concreto SIEMPRE gana sobre un "port_range" que la
  contenga (permite tener 1 puerto especial dentro de un mar de decoys).
- "proto" puede ser "tcp" (def.) o "udp".
- modos: "banner" (envia banner al conectar), "http" (responde HTTP/1.1),
  "echo" (lee datos del cliente y los devuelve con el banner como prefijo).
"""
import json
import os
import socket
import sys
import threading
import time

CONFIG_PATH = os.environ.get("PORTSRV_CONFIG", "/etc/portsrv.json")


def log(msg):
    sys.stdout.write("[portsrv] %s\n" % msg)
    sys.stdout.flush()


def load_config(path):
    with open(path, "r") as fh:
        cfg = json.load(fh)
    default_close = int(cfg.get("default_close_ms", 1500))
    # Mapa puerto/proto -> spec. Primero rangos, luego puertos concretos (ganan).
    specs = {}  # (proto, port) -> spec
    for entry in cfg.get("ports", []):
        proto = entry.get("proto", "tcp").lower()
        if "port_range" in entry:
            lo, hi = entry["port_range"]
            for p in range(int(lo), int(hi) + 1):
                specs[(proto, p)] = entry
    for entry in cfg.get("ports", []):
        proto = entry.get("proto", "tcp").lower()
        if "port" in entry:
            specs[(proto, int(entry["port"]))] = entry
    return specs, default_close


def build_http_response(spec):
    status = spec.get("http_status", "200 OK")
    body = spec.get("http_body", "<html><body>recon-lab</body></html>")
    body_bytes = body.encode("utf-8", "replace")
    headers = dict(spec.get("http_headers", {}))
    headers.setdefault("Server", "nginx/1.24.0")
    headers.setdefault("Content-Type", "text/html; charset=utf-8")
    headers["Content-Length"] = str(len(body_bytes))
    headers.setdefault("Connection", "close")
    lines = ["HTTP/1.1 %s" % status]
    for k, v in headers.items():
        lines.append("%s: %s" % (k, v))
    head = ("\r\n".join(lines) + "\r\n\r\n").encode("utf-8", "replace")
    return head + body_bytes


def handle_tcp_conn(conn, addr, spec, default_close):
    try:
        conn.settimeout(8.0)
        mode = spec.get("mode", "banner")
        if mode == "http":
            try:
                conn.recv(4096)  # leer (e ignorar) la peticion
            except Exception:
                pass
            conn.sendall(build_http_response(spec))
        elif mode == "echo":
            banner = spec.get("banner", "")
            if banner:
                conn.sendall(banner.encode("utf-8", "replace"))
            try:
                data = conn.recv(4096)
                if data:
                    conn.sendall(data)
            except Exception:
                pass
        else:  # banner
            banner = spec.get("banner", "recon-lab service\r\n")
            conn.sendall(banner.encode("utf-8", "replace"))
            time.sleep(default_close / 1000.0)
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def serve_tcp(port, spec, default_close):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind(("0.0.0.0", port))
    except OSError as exc:
        log("NO se pudo bind TCP %d: %s" % (port, exc))
        return
    srv.listen(64)
    log("TCP %d (%s) escuchando" % (port, spec.get("mode", "banner")))
    while True:
        try:
            conn, addr = srv.accept()
        except Exception:
            continue
        t = threading.Thread(
            target=handle_tcp_conn, args=(conn, addr, spec, default_close)
        )
        t.daemon = True
        t.start()


def serve_udp(port, spec):
    srv = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind(("0.0.0.0", port))
    except OSError as exc:
        log("NO se pudo bind UDP %d: %s" % (port, exc))
        return
    log("UDP %d escuchando" % port)
    banner = spec.get("banner", "recon-lab udp\n").encode("utf-8", "replace")
    while True:
        try:
            data, addr = srv.recvfrom(4096)
            srv.sendto(banner, addr)
        except Exception:
            continue


def main():
    if not os.path.exists(CONFIG_PATH):
        log("No existe config %s — nada que servir." % CONFIG_PATH)
        # Mantener vivo el contenedor de todos modos.
        while True:
            time.sleep(3600)
    specs, default_close = load_config(CONFIG_PATH)
    threads = []
    for (proto, port), spec in sorted(specs.items(), key=lambda kv: kv[0][1]):
        if proto == "udp":
            t = threading.Thread(target=serve_udp, args=(port, spec))
        else:
            t = threading.Thread(
                target=serve_tcp, args=(port, spec, default_close)
            )
        t.daemon = True
        t.start()
        threads.append(t)
    log("Total puertos servidos: %d" % len(threads))
    # Bucle principal: mantener vivo el proceso (PID 1 del contenedor).
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
