#!/usr/bin/env python3
# =====================================================================
# Operación Red Recon — Reinicio de la base de datos del scoreboard
# ---------------------------------------------------------------------
# Borra usuarios, resoluciones y pistas reveladas, y recrea las tablas
# vacías. Útil entre cohortes de alumnos.
#
# Uso dentro del contenedor:  python3 /app/reset_db.py
# =====================================================================
import os
import sqlite3

# Misma ubicación que usa la app (volumen /data).
DB_PATH = os.environ.get("RECON_DB", "/data/recon.db")

SCHEMA = """
DROP TABLE IF EXISTS solves;
DROP TABLE IF EXISTS hints;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    callsign   TEXT PRIMARY KEY,
    created_ts INTEGER NOT NULL
);
CREATE TABLE solves (
    callsign   TEXT NOT NULL,
    mission_id TEXT NOT NULL,
    ts         INTEGER NOT NULL,
    PRIMARY KEY (callsign, mission_id)
);
CREATE TABLE hints (
    callsign   TEXT NOT NULL,
    mission_id TEXT NOT NULL,
    idx        INTEGER NOT NULL,
    PRIMARY KEY (callsign, mission_id, idx)
);
"""


def main():
    os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    try:
        con.executescript(SCHEMA)
        con.commit()
        print("[reset_db] Base de datos reiniciada en %s" % DB_PATH)
    finally:
        con.close()


if __name__ == "__main__":
    main()
