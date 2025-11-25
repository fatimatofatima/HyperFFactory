CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  scope TEXT,
  status TEXT,
  priority INTEGER,
  created_at TEXT,
  updated_at TEXT
, code TEXT, title TEXT, stage TEXT, category TEXT, task TEXT, owner TEXT, last_note TEXT, plan_ref TEXT);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE quality_checks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  check_name TEXT,
  result TEXT,
  score INTEGER,
  details TEXT,
  ts TEXT
);
CREATE TABLE experiences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT UNIQUE,
  runs_total INTEGER DEFAULT 0,
  runs_success INTEGER DEFAULT 0,
  runs_failed INTEGER DEFAULT 0,
  success_rate REAL DEFAULT 0.0,
  experience_level TEXT
);
CREATE TABLE incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  error_type TEXT,
  error_message TEXT,
  severity TEXT,
  ts TEXT,
  context TEXT
);
CREATE TABLE progress_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  script_name TEXT,
  action TEXT,
  path TEXT,
  status TEXT,
  details TEXT,
  ts TEXT
, actor TEXT, scope TEXT);
CREATE UNIQUE INDEX idx_tasks_plan_ref_unique ON tasks(plan_ref);
