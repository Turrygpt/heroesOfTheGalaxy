"""Закрытое хранилище ответов и анонимных сессий плейтеста."""

import json
import os
import sqlite3
import sys
from pathlib import Path


DB_PATH = Path(os.environ.get("HOTG_PLAYTEST_DB", "/var/lib/hotg-playtest/responses.sqlite3"))
LEGACY_PATH = Path(os.environ.get("HOTG_PLAYTEST_LEGACY", "/var/lib/hotg-playtest/responses.jsonl"))


def open_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    fresh = not DB_PATH.exists()
    connection = sqlite3.connect(DB_PATH, timeout=10)
    if fresh:
        os.chmod(DB_PATH, 0o600)
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("CREATE TABLE IF NOT EXISTS sessions (session_hash TEXT PRIMARY KEY)")
    connection.execute(
        "CREATE TABLE IF NOT EXISTS submissions ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "session_hash TEXT UNIQUE REFERENCES sessions(session_hash), "
        "answers_json TEXT NOT NULL)"
    )
    connection.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    connection.commit()
    return connection


def migrate_legacy(connection):
    connection.execute("BEGIN IMMEDIATE")
    with connection:
        if connection.execute("SELECT 1 FROM meta WHERE key = 'legacy_imported'").fetchone():
            return
        if LEGACY_PATH.exists():
            with LEGACY_PATH.open(encoding="utf-8") as source:
                for line in source:
                    if not line.strip():
                        continue
                    answers = json.loads(line)
                    if not isinstance(answers, dict):
                        raise ValueError("Неверная запись в старом хранилище")
                    connection.execute(
                        "INSERT INTO submissions (session_hash, answers_json) VALUES (NULL, ?)",
                        (json.dumps(answers, ensure_ascii=False, separators=(",", ":")),),
                    )
        connection.execute("INSERT INTO meta (key, value) VALUES ('legacy_imported', '1')")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action not in {"init", "session", "submit", "stats", "export"}:
        raise ValueError("Неизвестная команда")
    connection = open_db()
    migrate_legacy(connection)
    if action == "init":
        result = {"status": "ok"}
    elif action == "stats":
        result = {
            "submissions": connection.execute("SELECT COUNT(*) FROM submissions").fetchone()[0],
            "legacy": connection.execute(
                "SELECT COUNT(*) FROM submissions WHERE session_hash IS NULL"
            ).fetchone()[0],
        }
    elif action == "export":
        for (answers_json,) in connection.execute("SELECT answers_json FROM submissions ORDER BY id"):
            print(answers_json)
        return
    else:
        payload = json.load(sys.stdin)
        session_hash = payload.get("session_hash")
        if not isinstance(session_hash, str) or len(session_hash) != 64 or any(
            character not in "0123456789abcdef" for character in session_hash
        ):
            raise ValueError("Неверная сессия")
        if action == "session":
            with connection:
                connection.execute(
                    "INSERT OR IGNORE INTO sessions (session_hash) VALUES (?)", (session_hash,)
                )
            result = {
                "submitted": connection.execute(
                    "SELECT 1 FROM submissions WHERE session_hash = ?", (session_hash,)
                ).fetchone() is not None
            }
        else:
            answers = payload.get("answers")
            if not isinstance(answers, dict):
                raise ValueError("Неверные ответы")
            with connection:
                connection.execute("BEGIN IMMEDIATE")
                if not connection.execute(
                    "SELECT 1 FROM sessions WHERE session_hash = ?", (session_hash,)
                ).fetchone():
                    result = {"status": "session_required"}
                elif connection.execute(
                    "SELECT 1 FROM submissions WHERE session_hash = ?", (session_hash,)
                ).fetchone():
                    result = {"status": "already_used"}
                else:
                    connection.execute(
                        "INSERT INTO submissions (session_hash, answers_json) VALUES (?, ?)",
                        (session_hash, json.dumps(answers, ensure_ascii=False, separators=(",", ":"))),
                    )
                    result = {"status": "accepted"}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
