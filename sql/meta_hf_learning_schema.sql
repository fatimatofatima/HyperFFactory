CREATE TABLE scripts (
  path          TEXT PRIMARY KEY,
  csv_id        INTEGER,
  role          TEXT,
  priority      INTEGER,
  system        TEXT,
  category      TEXT,
  name          TEXT,
  first_seen_at TEXT,
  last_seen_at  TEXT
);
CREATE INDEX idx_scripts_system
  ON scripts(system);
CREATE INDEX idx_scripts_role
  ON scripts(role);
CREATE INDEX idx_scripts_category
  ON scripts(category);
CREATE TABLE experiences (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  source      TEXT NOT NULL,     -- من أين جاءت الخبرة (health_all / sf-core / ffactory / manual_note / ...)
  pattern     TEXT NOT NULL,     -- نمط أو ملاحظة
  outcome     TEXT NOT NULL,     -- النتيجة (expected_behavior / anomaly / workaround / ...)
  confidence  REAL NOT NULL,     -- 0–1
  tags        TEXT,              -- نص حر (csv / json)
  created_at  TEXT NOT NULL
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX idx_experiences_source
  ON experiences(source);
CREATE INDEX idx_experiences_created_at
  ON experiences(created_at);
CREATE INDEX idx_experiences_confidence ON experiences(confidence);
CREATE TABLE learning (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  source     TEXT NOT NULL,
  pattern    TEXT NOT NULL,
  outcome    TEXT,
  confidence REAL,
  ts         TEXT NOT NULL
);
CREATE INDEX idx_learning_source_ts ON learning(source, ts);
CREATE INDEX idx_learning_pattern_ts
  ON learning (pattern, ts);
CREATE TABLE learning_skill_states (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  actor       TEXT,
  skill_key   TEXT,
  level       TEXT,
  samples     INTEGER DEFAULT 0,
  meta_json   TEXT,
  last_update TEXT DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX idx_skill_state_actor_skill
  ON learning_skill_states(actor, skill_key);
