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
    connection.execute(
        "CREATE TABLE IF NOT EXISTS reviews ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "session_hash TEXT UNIQUE REFERENCES sessions(session_hash), "
        "author TEXT NOT NULL, body TEXT NOT NULL, rating INTEGER, "
        "status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'published', 'rejected')), "
        "created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')), "
        "updated_at TEXT, published_at TEXT)"
    )
    connection.execute(
        "CREATE TABLE IF NOT EXISTS download_counts ("
        "version TEXT PRIMARY KEY, count INTEGER NOT NULL DEFAULT 0)"
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
    if action not in {
        "init", "session", "submit", "stats", "export",
        "review_public", "review_list", "review_submit", "review_status",
        "download_hit", "download_stats",
    }:
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
            "reviews_pending": connection.execute(
                "SELECT COUNT(*) FROM reviews WHERE status = 'pending'"
            ).fetchone()[0],
        }
    elif action == "export":
        for (answers_json,) in connection.execute("SELECT answers_json FROM submissions ORDER BY id"):
            print(answers_json)
        return
    elif action == "review_public":
        rows = connection.execute(
            "SELECT id, author, body, rating, published_at FROM reviews "
            "WHERE status = 'published' ORDER BY published_at DESC, id DESC LIMIT 30"
        ).fetchall()
        result = {"reviews": [
            dict(zip(("id", "author", "body", "rating", "published_at"), row))
            for row in rows
        ]}
    elif action == "review_list":
        rows = connection.execute(
            "SELECT id, author, body, rating, status, created_at, updated_at, published_at "
            "FROM reviews ORDER BY id DESC LIMIT 200"
        ).fetchall()
        result = {"reviews": [
            dict(zip(("id", "author", "body", "rating", "status", "created_at", "updated_at", "published_at"), row))
            for row in rows
        ]}
    elif action == "review_status":
        payload = json.load(sys.stdin)
        review_id = payload.get("id")
        status = payload.get("status")
        if isinstance(review_id, bool) or not isinstance(review_id, int) or review_id < 1:
            raise ValueError("Неверный отзыв")
        if status not in {"pending", "published", "rejected"}:
            raise ValueError("Неверный статус")
        with connection:
            cursor = connection.execute(
                "UPDATE reviews SET status = ?, "
                "updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'), "
                "published_at = CASE WHEN ? = 'published' "
                "THEN strftime('%Y-%m-%dT%H:%M:%SZ', 'now') ELSE NULL END "
                "WHERE id = ?",
                (status, status, review_id),
            )
        result = {"status": "updated" if cursor.rowcount else "not_found"}
    elif action == "download_stats":
        rows = connection.execute(
            "SELECT version, count FROM download_counts ORDER BY version DESC"
        ).fetchall()
        result = {
            "total": sum(count for _, count in rows),
            "versions": [{"version": version, "count": count} for version, count in rows],
        }
    elif action == "download_hit":
        payload = json.load(sys.stdin)
        version = payload.get("version")
        if not isinstance(version, str) or not 1 <= len(version) <= 20 or not all(
            character in "0123456789." for character in version
        ):
            raise ValueError("Неверная версия")
        with connection:
            connection.execute(
                "INSERT INTO download_counts (version, count) VALUES (?, 1) "
                "ON CONFLICT(version) DO UPDATE SET count = count + 1",
                (version,),
            )
        result = {"status": "counted"}
    elif action == "review_submit":
        payload = json.load(sys.stdin)
        session_hash = payload.get("session_hash")
        author = payload.get("author")
        body = payload.get("body")
        rating = payload.get("rating")
        if not isinstance(session_hash, str) or len(session_hash) != 64 or any(
            character not in "0123456789abcdef" for character in session_hash
        ):
            raise ValueError("Неверная сессия")
        if not isinstance(author, str) or not 1 <= len(author) <= 40:
            raise ValueError("Неверное имя")
        if not isinstance(body, str) or not 5 <= len(body) <= 2000:
            raise ValueError("Неверный текст")
        if rating is not None and (isinstance(rating, bool) or not isinstance(rating, int) or rating not in range(1, 6)):
            raise ValueError("Неверная оценка")
        with connection:
            connection.execute("BEGIN IMMEDIATE")
            if not connection.execute(
                "SELECT 1 FROM sessions WHERE session_hash = ?", (session_hash,)
            ).fetchone():
                result = {"status": "session_required"}
            elif connection.execute(
                "SELECT 1 FROM reviews WHERE session_hash = ?", (session_hash,)
            ).fetchone():
                result = {"status": "already_used"}
            else:
                connection.execute(
                    "INSERT INTO reviews (session_hash, author, body, rating) VALUES (?, ?, ?, ?)",
                    (session_hash, author, body, rating),
                )
                result = {"status": "pending"}
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
