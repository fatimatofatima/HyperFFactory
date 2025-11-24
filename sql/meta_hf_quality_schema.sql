CREATE TABLE quality_checks (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  actor       TEXT NOT NULL,   -- من ينفّذ الفحص (hf_health_all / sf-core / ffactory_health / ...)
  check_name  TEXT NOT NULL,   -- اسم الفحص (smartfriend_services, ffactory_docker, backup_policy, ...)
  result      TEXT NOT NULL,   -- PASS / FAIL / WARN / SKIP
  score       INTEGER NOT NULL, -- 0–100
  details     TEXT,            -- وصف حر
  tags        TEXT,            -- نص حر (csv/json بسيط)
  ts          TEXT NOT NULL    -- وقت التنفيذ
, scope TEXT);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX idx_quality_ts         ON quality_checks(ts);
CREATE INDEX idx_quality_actor      ON quality_checks(actor);
CREATE INDEX idx_quality_check_name ON quality_checks(check_name);
CREATE INDEX idx_quality_result     ON quality_checks(result);
CREATE INDEX idx_quality_checks_result ON quality_checks(result);
CREATE INDEX idx_quality_checks_ts     ON quality_checks(ts);
CREATE TABLE quality_events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  system_name  TEXT,
  metric_name  TEXT,
  metric_value REAL,
  window_label TEXT,
  meta_json    TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
);
CREATE INDEX idx_quality_events_sys_metric
  ON quality_events(system_name, metric_name);
