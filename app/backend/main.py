"""Minimal API for the PoC: health, DB probe, and replica metadata."""

from __future__ import annotations

import os
from contextlib import contextmanager

import psycopg2
from fastapi import FastAPI, HTTPException

app = FastAPI(title="PoC Backend", version="0.1.0")

REPLICA_INDEX = os.getenv("REPLICA_INDEX", "0")


@contextmanager
def db_conn():
    conn = psycopg2.connect(
        host=os.environ["PGHOST"],
        port=int(os.environ.get("PGPORT", "5432")),
        user=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
        dbname=os.environ["PGDATABASE"],
        connect_timeout=5,
    )
    try:
        yield conn
    finally:
        conn.close()


@app.get("/health")
def health():
    return {"status": "ok", "replica": int(REPLICA_INDEX)}


@app.get("/api/status")
def api_status():
    try:
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                row = cur.fetchone()
        return {
            "database": "connected",
            "query": row,
            "replica": int(REPLICA_INDEX),
        }
    except Exception as exc:  # noqa: BLE001 — PoC surfaces failure clearly
        raise HTTPException(status_code=503, detail=f"database_unavailable: {exc!s}") from exc
