-- HyperFFactory – Unified Data Model (Reference Schema)
-- لا يتم تشغيله تلقائياً؛ يُستخدم فقط عند رغبتك في توحيد DB.

CREATE TABLE IF NOT EXISTS users (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id  TEXT UNIQUE,
  display_name TEXT,
  created_at   TEXT DEFAULT (datetime('now')),
  meta_json    TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id       INTEGER NOT NULL,
  source_system TEXT,
  started_at    TEXT DEFAULT (datetime('now')),
  ended_at      TEXT,
  meta_json     TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  INTEGER NOT NULL,
  role        TEXT,
  content     TEXT,
  created_at  TEXT DEFAULT (datetime('now')),
  meta_json   TEXT,
  FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS evaluations (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id  INTEGER NOT NULL,
  score       REAL,
  label       TEXT,
  created_at  TEXT DEFAULT (datetime('now')),
  meta_json   TEXT,
  FOREIGN KEY (message_id) REFERENCES messages(id)
);
