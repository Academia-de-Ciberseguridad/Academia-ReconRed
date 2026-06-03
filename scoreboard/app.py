#!/usr/bin/env python3
# =====================================================================
# Operación Red Recon — Scoreboard CTF (aplicación Flask)
# ---------------------------------------------------------------------
# Plataforma de gamificación del laboratorio educativo. Identidad simple
# por "callsign" (alias, sin contraseña: es un lab aislado). Persistencia
# en SQLite sobre el volumen /data. Carga las misiones desde challenges.yml.
#
# Arranque en producción:  gunicorn -b 0.0.0.0:8000 -w 2 app:create_app()
# =====================================================================
import os
import sqlite3
import time

import yaml
from flask import (
    Flask,
    abort,
    g,
    redirect,
    render_template,
    request,
    session,
    url_for,
)

# --------------------------------------------------------------------- Rutas
APP_DIR = os.path.dirname(os.path.abspath(__file__))
CHALLENGES_PATH = os.environ.get(
    "CHALLENGES_PATH", os.path.join(APP_DIR, "challenges.yml")
)
# La BD vive en el volumen /data (configurable para pruebas locales).
DB_PATH = os.environ.get("RECON_DB", "/data/recon.db")

# El flag maestro de M12 se "desclasifica" cuando se cumplen los requisitos.
MASTER_FLAG = "RECON{m4st3r_r3c0n_c0mpl3t3}"

# --------------------------------------------------------- Rangos (LAB-SPEC §5)
# (umbral_inferior, nombre). Ordenados de mayor a menor para resolver el rango.
RANKS = [
    (1500, "Maestro Recon"),
    (1000, "Especialista"),
    (600, "Analista"),
    (300, "Operador"),
    (100, "Explorador"),
    (0, "Recluta"),
]

# Mapa insignia -> misión que la concede (además de "first-blood").
BADGE_BY_MISSION = {
    "M09": "udp-diver",
    "M10": "packet-smith",
    "M11": "ghost",
    "M12": "cartographer",
}


# ===================================================================== Misiones
def load_challenges(path):
    """Carga y normaliza challenges.yml en estructuras en memoria."""
    with open(path, "r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    items = data.get("challenges", [])
    by_id = {}
    order = []
    for raw in items:
        mid = raw["id"]
        mission = {
            "id": mid,
            "title": raw.get("title", mid),
            "category": raw.get("category", ""),
            "points": int(raw.get("points", 0)),
            "target": raw.get("target", ""),
            "brief": raw.get("brief", "").strip(),
            "hints": list(raw.get("hints", []) or []),
            "type": raw.get("type", "flag"),
            "flag": raw.get("flag"),
            "accept": list(raw.get("accept", []) or []),
            "requires": list(raw.get("requires", []) or []),
            "badge": raw.get("badge"),
        }
        by_id[mid] = mission
        order.append(mid)
    return by_id, order


# ===================================================================== Base datos
def get_db():
    """Conexión SQLite por petición (almacenada en el contexto de app `g`)."""
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


def close_db(exc=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Crea el directorio /data y las tablas si no existen."""
    os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    try:
        con.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                callsign   TEXT PRIMARY KEY,
                created_ts INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS solves (
                callsign   TEXT NOT NULL,
                mission_id TEXT NOT NULL,
                ts         INTEGER NOT NULL,
                PRIMARY KEY (callsign, mission_id)
            );
            CREATE TABLE IF NOT EXISTS hints (
                callsign   TEXT NOT NULL,
                mission_id TEXT NOT NULL,
                idx        INTEGER NOT NULL,
                PRIMARY KEY (callsign, mission_id, idx)
            );
            """
        )
        con.commit()
    finally:
        con.close()


# ===================================================================== Lógica
def rank_for_points(points):
    """Devuelve el nombre de rango para una puntuación dada (LAB-SPEC §5)."""
    for threshold, name in RANKS:
        if points >= threshold:
            return name
    return RANKS[-1][1]


def next_rank_info(points):
    """(rango_actual, siguiente_umbral_o_None) para la barra de progreso."""
    current = rank_for_points(points)
    # RANKS está de mayor a menor; recórrelo de menor a mayor buscando el techo.
    for threshold, _name in reversed(RANKS):
        if threshold > points:
            return current, threshold
    return current, None  # ya es Maestro Recon (sin techo superior)


def solved_ids(db, callsign):
    """Conjunto de ids de misiones resueltas por el usuario."""
    rows = db.execute(
        "SELECT mission_id FROM solves WHERE callsign = ?", (callsign,)
    ).fetchall()
    return {r["mission_id"] for r in rows}


def revealed_hints(db, callsign, mission_id):
    """Nº de hints revelados (índices contiguos desde 0) para una misión."""
    rows = db.execute(
        "SELECT idx FROM hints WHERE callsign = ? AND mission_id = ?",
        (callsign, mission_id),
    ).fetchall()
    return len(rows)


def user_points(challenges, solved):
    """Suma de puntos de las misiones resueltas."""
    return sum(challenges[mid]["points"] for mid in solved if mid in challenges)


def is_unlocked(mission, solved):
    """¿Están cumplidos los `requires` de la misión?"""
    return all(req in solved for req in mission["requires"])


def compute_badges(challenges, order, solved):
    """Insignias del usuario a partir de sus solves."""
    badges = []
    if solved:
        badges.append("first-blood")
    for mid in order:
        if mid in solved:
            b = BADGE_BY_MISSION.get(mid)
            if b:
                badges.append(b)
    return badges


def norm(value):
    return (value or "").strip()


# ===================================================================== Factory
def create_app():
    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.secret_key = os.environ.get("RECON_SECRET", "recon-lab-dev-secret")

    challenges, order = load_challenges(CHALLENGES_PATH)
    app.config["CHALLENGES"] = challenges
    app.config["ORDER"] = order

    init_db()
    app.teardown_appcontext(close_db)

    # ---------------------------------------------------------- Utilidades
    def current_callsign():
        return session.get("callsign")

    def require_login():
        cs = current_callsign()
        if not cs:
            return None
        return cs

    def leaderboard_rows():
        """
        Ranking: puntos desc, desempate por timestamp del ÚLTIMO solve
        (antes = mejor). Devuelve lista de dicts enriquecidos.
        """
        db = get_db()
        users = db.execute("SELECT callsign FROM users").fetchall()
        rows = []
        for u in users:
            cs = u["callsign"]
            solved = solved_ids(db, cs)
            pts = user_points(challenges, solved)
            last_ts = db.execute(
                "SELECT MAX(ts) AS m FROM solves WHERE callsign = ?", (cs,)
            ).fetchone()["m"]
            rows.append(
                {
                    "callsign": cs,
                    "points": pts,
                    "flags": len(solved),
                    "rank": rank_for_points(pts),
                    "badges": compute_badges(challenges, order, solved),
                    "last_ts": last_ts if last_ts is not None else 1 << 62,
                }
            )
        # puntos desc, último solve asc (antes gana)
        rows.sort(key=lambda r: (-r["points"], r["last_ts"]))
        return rows

    # ----------------------------------------------------------------- Rutas
    @app.route("/healthz")
    def healthz():
        return "ok", 200

    @app.route("/")
    def index():
        board = leaderboard_rows()[:20]
        return render_template(
            "index.html",
            callsign=current_callsign(),
            leaderboard=board,
            total_missions=len(order),
        )

    @app.route("/login", methods=["POST"])
    def login():
        callsign = norm(request.form.get("callsign"))
        # Sanea: longitud razonable y caracteres seguros.
        callsign = callsign[:32]
        if not callsign:
            return redirect(url_for("index"))
        db = get_db()
        existing = db.execute(
            "SELECT callsign FROM users WHERE callsign = ?", (callsign,)
        ).fetchone()
        if not existing:
            db.execute(
                "INSERT INTO users (callsign, created_ts) VALUES (?, ?)",
                (callsign, int(time.time())),
            )
            db.commit()
        session["callsign"] = callsign
        return redirect(url_for("missions"))

    @app.route("/logout")
    def logout():
        session.clear()
        return redirect(url_for("index"))

    @app.route("/missions")
    def missions():
        cs = require_login()
        if not cs:
            return redirect(url_for("index"))
        db = get_db()
        solved = solved_ids(db, cs)
        pts = user_points(challenges, solved)
        rank, next_threshold = next_rank_info(pts)

        cards = []
        for mid in order:
            m = challenges[mid]
            unlocked = is_unlocked(m, solved)
            if mid in solved:
                state = "solved"
            elif unlocked:
                state = "available"
            else:
                state = "locked"
            missing = [r for r in m["requires"] if r not in solved]
            cards.append(
                {
                    "id": mid,
                    "title": m["title"],
                    "category": m["category"],
                    "points": m["points"],
                    "n_hints": len(m["hints"]),
                    "state": state,
                    "missing": missing,
                }
            )

        progress_pct = 0
        if order:
            progress_pct = int(round(100 * len(solved) / len(order)))

        return render_template(
            "missions.html",
            callsign=cs,
            cards=cards,
            points=pts,
            rank=rank,
            next_threshold=next_threshold,
            solved_count=len(solved),
            total_missions=len(order),
            progress_pct=progress_pct,
        )

    @app.route("/mission/<mid>")
    def mission(mid):
        cs = require_login()
        if not cs:
            return redirect(url_for("index"))
        m = challenges.get(mid)
        if not m:
            abort(404)
        db = get_db()
        solved = solved_ids(db, cs)
        unlocked = is_unlocked(m, solved)
        n_revealed = revealed_hints(db, cs, mid)
        missing = [r for r in m["requires"] if r not in solved]

        # M12 (boss): si cumple requisitos, desclasifica el flag maestro.
        reveal_master = None
        if mid == "M12" and unlocked:
            reveal_master = MASTER_FLAG

        return render_template(
            "mission.html",
            callsign=cs,
            mission=m,
            already_solved=(mid in solved),
            unlocked=unlocked,
            missing=missing,
            n_revealed=n_revealed,
            revealed_hints=m["hints"][:n_revealed],
            reveal_master=reveal_master,
        )

    @app.route("/submit", methods=["POST"])
    def submit():
        cs = require_login()
        if not cs:
            return redirect(url_for("index"))
        mid = norm(request.form.get("mission_id"))
        answer = norm(request.form.get("answer"))
        m = challenges.get(mid)
        if not m:
            abort(404)

        db = get_db()
        solved = solved_ids(db, cs)

        # Bloqueo por requisitos no cumplidos.
        if not is_unlocked(m, solved):
            missing = [r for r in m["requires"] if r not in solved]
            return _mission_with_feedback(
                cs,
                m,
                solved,
                db,
                ok=False,
                message="Misión bloqueada. Faltan: " + ", ".join(missing) + ".",
            )

        if mid in solved:
            return _mission_with_feedback(
                cs, m, solved, db, ok=True,
                message="Ya habías resuelto esta misión. ¡Buen trabajo, operador!",
            )

        correct = _check_answer(m, answer)
        if not correct:
            return _mission_with_feedback(
                cs, m, solved, db, ok=False,
                message="Negativo. La respuesta no coincide. Revisa tus pistas.",
            )

        # Correcto: registra el solve y concede badges (implícito por solves).
        ts = int(time.time())
        try:
            db.execute(
                "INSERT INTO solves (callsign, mission_id, ts) VALUES (?, ?, ?)",
                (cs, mid, ts),
            )
            db.commit()
        except sqlite3.IntegrityError:
            db.rollback()  # carrera: ya estaba resuelta

        solved = solved_ids(db, cs)
        gained = []
        # Mensaje sobre badges recién obtenidos.
        if BADGE_BY_MISSION.get(mid):
            gained.append(BADGE_BY_MISSION[mid])
        if len(solved) == 1:
            gained.append("first-blood")
        extra = ""
        if gained:
            extra = " Insignia(s): " + ", ".join(sorted(set(gained))) + "."
        return _mission_with_feedback(
            cs, m, solved, db, ok=True,
            message="¡Correcto! +%d puntos.%s" % (m["points"], extra),
        )

    def _check_answer(mission, answer):
        if mission["type"] == "flag":
            # Comparación exacta tras strip; insensible a may/min para robustez.
            return answer.strip().lower() == (mission["flag"] or "").strip().lower()
        # type == answer: cualquiera de accept, insensible a may/min.
        wanted = {a.strip().lower() for a in mission["accept"]}
        return answer.strip().lower() in wanted

    def _mission_with_feedback(cs, m, solved, db, ok, message):
        unlocked = is_unlocked(m, solved)
        n_revealed = revealed_hints(db, cs, m["id"])
        missing = [r for r in m["requires"] if r not in solved]
        reveal_master = MASTER_FLAG if (m["id"] == "M12" and unlocked) else None
        return render_template(
            "mission.html",
            callsign=cs,
            mission=m,
            already_solved=(m["id"] in solved),
            unlocked=unlocked,
            missing=missing,
            n_revealed=n_revealed,
            revealed_hints=m["hints"][:n_revealed],
            reveal_master=reveal_master,
            feedback_ok=ok,
            feedback_msg=message,
        )

    @app.route("/hint/<mid>", methods=["POST"])
    def hint(mid):
        cs = require_login()
        if not cs:
            return redirect(url_for("index"))
        m = challenges.get(mid)
        if not m:
            abort(404)
        db = get_db()
        n_revealed = revealed_hints(db, cs, mid)
        if n_revealed < len(m["hints"]):
            try:
                db.execute(
                    "INSERT INTO hints (callsign, mission_id, idx) "
                    "VALUES (?, ?, ?)",
                    (cs, mid, n_revealed),
                )
                db.commit()
            except sqlite3.IntegrityError:
                db.rollback()
        return redirect(url_for("mission", mid=mid))

    @app.route("/leaderboard")
    def leaderboard():
        return render_template(
            "index.html",
            callsign=current_callsign(),
            leaderboard=leaderboard_rows(),
            total_missions=len(order),
            full_board=True,
        )

    @app.route("/profile")
    def profile():
        cs = require_login()
        if not cs:
            return redirect(url_for("index"))
        db = get_db()
        solved = solved_ids(db, cs)
        pts = user_points(challenges, solved)
        rank, next_threshold = next_rank_info(pts)
        badges = compute_badges(challenges, order, solved)
        solved_list = [
            {"id": mid, "title": challenges[mid]["title"],
             "points": challenges[mid]["points"]}
            for mid in order if mid in solved
        ]
        progress_pct = 0
        if order:
            progress_pct = int(round(100 * len(solved) / len(order)))
        return render_template(
            "profile.html",
            callsign=cs,
            points=pts,
            rank=rank,
            next_threshold=next_threshold,
            badges=badges,
            solved_list=solved_list,
            solved_count=len(solved),
            total_missions=len(order),
            progress_pct=progress_pct,
        )

    return app


# Permite también `gunicorn app:app` además de `app:create_app()`.
app = create_app()


if __name__ == "__main__":
    # Modo desarrollo (no para producción): `python3 app.py`.
    app.run(host="0.0.0.0", port=8000, debug=True)
