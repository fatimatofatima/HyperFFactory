CREATE TABLE errors (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  actor         TEXT NOT NULL,   -- من الذي سجّل/رصد الخطأ (hf_health_all / sf-core / ffactory_controller / ...)
  error_type    TEXT NOT NULL,   -- نوع الخطأ (service_fail / db_issue / disk_space / ...)
  error_message TEXT NOT NULL,   -- رسالة مختصرة
  severity      TEXT NOT NULL CHECK(severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  context       TEXT,            -- تفاصيل إضافية (stacktrace مختصر / خدمة محددة / ...)
  tags          TEXT,            -- نص حر
  ts            TEXT NOT NULL    -- وقت التسجيل
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE INDEX idx_errors_ts        ON errors(ts);
CREATE INDEX idx_errors_severity  ON errors(severity);
CREATE INDEX idx_errors_actor     ON errors(actor);
CREATE INDEX idx_errors_type      ON errors(error_type);
CREATE TABLE error_events (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      source       TEXT NOT NULL,    -- hyper, smartfriend, ffactory, systemd, docker...
      component    TEXT NOT NULL,    -- service/script/db/stack...
      error_code   TEXT,
      severity     TEXT NOT NULL,    -- INFO/WARN/ERROR/CRITICAL
      message      TEXT NOT NULL,
      context      TEXT,             -- JSON أو نص حر
      created_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE error_stats (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      source       TEXT NOT NULL,
      component    TEXT NOT NULL,
      severity     TEXT NOT NULL,
      window_key   TEXT NOT NULL,    -- e.g. 2025-11-25, 2025-11-25T05, ...
      error_count  INTEGER NOT NULL DEFAULT 0,
      last_update  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
