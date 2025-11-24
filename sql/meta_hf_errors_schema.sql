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
