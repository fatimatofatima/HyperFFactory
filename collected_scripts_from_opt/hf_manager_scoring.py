#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
hf_manager_scoring.py
طبقة Scoring فوق manager_brain:
- تقرأ run/manager_execution_plan.txt
- تحسب Score لكل عامل/سكربت باستخدام:
  * config/agents.yaml (priority / skills)
  * ai/memory/quality_status.json (feedback / KPS)
  * data/metrics/agent_*.json (KPS/feedback إضافي عند توفرها)
- تعيد ترتيب أوامر CMD حسب أعلى Score
- تكتب الخطة المعدّلة في:
  * run/manager_execution_plan_scored.txt
  * وتحدّث run/manager_execution_plan.txt لاستخدامها مباشرة من manager_engine
- تسجّل درجات العوامل في ai/memory/manager_scores.json
"""

import os
import json
from pathlib import Path
from typing import Dict, Tuple, List

try:
    import yaml  # type: ignore
except Exception:
    yaml = None  # سيتم التعامل مع غياب PyYAML بهدوء


ROOT = Path(__file__).resolve().parent.parent
RUN_DIR = ROOT / "run"
CONFIG_DIR = ROOT / "config"
MEMORY_DIR = ROOT / "ai" / "memory"
METRICS_DIR = ROOT / "data" / "metrics"

PLAN_FILE = RUN_DIR / "manager_execution_plan.txt"
PLAN_SCORED_FILE = RUN_DIR / "manager_execution_plan_scored.txt"
SCORES_JSON = MEMORY_DIR / "manager_scores.json"


def load_agents_config() -> Tuple[Dict[str, float], Dict[str, str]]:
    """
    قراءة config/agents.yaml
    ترجع:
      - agent_priorities: {agent_id -> priority}
      - alias_to_agent: {alias_from_script -> agent_id}
    """
    priorities: Dict[str, float] = {}
    alias_to_agent: Dict[str, str] = {}

    if not yaml:
        return priorities, alias_to_agent

    agents_file = CONFIG_DIR / "agents.yaml"
    if not agents_file.exists():
        return priorities, alias_to_agent

    try:
        data = yaml.safe_load(agents_file.read_text(encoding="utf-8"))
    except Exception:
        return priorities, alias_to_agent

    def derive_alias_from_script(script: str) -> str:
        import os as _os

        base = _os.path.basename(script)
        if base.endswith(".sh"):
            base = base[:-3]
        if base.startswith("hf_run_"):
            base = base[len("hf_run_") :]
        elif base.startswith("run_"):
            base = base[len("run_") :]
        return base

    items: List[dict]
    if isinstance(data, dict) and "agents" in data and isinstance(data["agents"], list):
        items = data["agents"]
    elif isinstance(data, list):
        items = data
    else:
        return priorities, alias_to_agent

    for item in items:
        if not isinstance(item, dict):
            continue
        agent_id = str(item.get("id") or "").strip()
        if not agent_id:
            continue
        prio = item.get("priority", 1)
        try:
            prio_f = float(prio)
        except Exception:
            prio_f = 1.0
        priorities[agent_id] = prio_f

        script = str(item.get("script") or "").strip()
        if script:
            alias = derive_alias_from_script(script)
            if alias:
                alias_to_agent[alias] = agent_id

    return priorities, alias_to_agent


def load_feedback_scores() -> Dict[str, float]:
    """
    تحميل درجات الأداء/التغذية الراجعة من:
      - ai/memory/quality_status.json (إن وجدت)
      - data/metrics/agent_kps.json / agent_feedback.json / agent_scores.json (إن وجدت)
    الشكل المتوقّع للملفات مرن:
      { "debug_expert": {"score": 0.9, "success_rate": 0.92}, ... }
      أو  { "debug_expert": 0.9, ... }
    """
    scores: Dict[str, float] = {}

    # 1) quality_status.json
    quality_file = MEMORY_DIR / "quality_status.json"
    for f in [quality_file]:
        if f.exists():
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
            except Exception:
                continue
            if isinstance(data, dict):
                for agent_id, entry in data.items():
                    val = None
                    if isinstance(entry, dict):
                        for key in ("score", "kps", "kpi", "success_rate"):
                            if key in entry and isinstance(entry[key], (int, float)):
                                val = float(entry[key])
                                break
                    elif isinstance(entry, (int, float)):
                        val = float(entry)
                    if val is not None:
                        scores[str(agent_id)] = val

    # 2) ملفات metrics الاختيارية تحت data/metrics
    if METRICS_DIR.exists():
        for name in ("agent_kps.json", "agent_feedback.json", "agent_scores.json"):
            f = METRICS_DIR / name
            if not f.exists():
                continue
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
            except Exception:
                continue
            if isinstance(data, dict):
                for agent_id, val in data.items():
                    if isinstance(val, (int, float)):
                        scores[str(agent_id)] = float(val)
                    elif isinstance(val, dict):
                        for key in ("score", "kps", "kpi", "success_rate"):
                            if key in val and isinstance(val[key], (int, float)):
                                scores[str(agent_id)] = float(val[key])
                                break

    return scores


def extract_cmd_and_alias(line: str) -> Tuple[str, str]:
    """
    من سطر الخطة "CMD: ./hf_run_debug_expert.sh ..."
    ترجع:
      cmd  = "./hf_run_debug_expert.sh"
      alias = "debug_expert"
    """
    line = line.strip()
    if not line.startswith("CMD:"):
        return "", ""
    body = line[4:].strip()
    if not body:
        return "", ""
    parts = body.split()
    cmd = parts[0]
    import os as _os

    base = cmd
    if base.startswith("./"):
        base = base[2:]
    base = _os.path.basename(base)
    if base.endswith(".sh"):
        base = base[:-3]
    if base.startswith("hf_run_"):
        alias = base[len("hf_run_") :]
    elif base.startswith("run_"):
        alias = base[len("run_") :]
    else:
        alias = base
    return cmd, alias


def compute_scores_for_plan() -> None:
    if not PLAN_FILE.exists():
        print(f"⚠️ لا يوجد ملف خطة للتقييم: {PLAN_FILE}")
        return

    lines = PLAN_FILE.read_text(encoding="utf-8").splitlines()

    agent_priorities, alias_to_agent = load_agents_config()
    feedback_scores = load_feedback_scores()

    scored_cmds: List[Tuple[float, str]] = []
    header_lines: List[str] = []
    cmd_lines: List[str] = []

    # فصل الهيدر عن أوامر CMD
    for line in lines:
        if line.strip().startswith("CMD:"):
            cmd_lines.append(line)
        else:
            header_lines.append(line)

    scores_dump: Dict[str, dict] = {}

    for line in cmd_lines:
        _, alias = extract_cmd_and_alias(line)
        if not alias:
            # لا يمكن استخراج alias → score صفر
            scored_cmds.append((0.0, line))
            continue

        agent_id = alias_to_agent.get(alias, alias)

        base_prio = agent_priorities.get(agent_id, 1.0)
        fb = feedback_scores.get(agent_id, 0.0)

        # معادلة بسيطة:
        # score = base_priority + feedback*10
        # حيث feedback يمكن أن يكون 0..1 أو قيمة عددية عامّة
        score = base_prio + fb * 10.0

        scores_dump[agent_id] = {
            "alias": alias,
            "base_priority": base_prio,
            "feedback": fb,
            "final_score": score,
        }

        scored_cmds.append((score, line))

    # Sort مستقر: الأعلى أولاً، ومع الحفاظ على ترتيب الأصلي عند تساوي score
    scored_cmds_sorted = sorted(
        enumerate(scored_cmds),
        key=lambda t: (-t[1][0], t[0]),
    )

    new_lines: List[str] = []
    new_lines.extend(header_lines)
    new_lines.append("# === Adjusted by hf_manager_scoring (higher score → earlier execution) ===")

    for _, (score, line) in scored_cmds_sorted:
        if " # score=" in line:
            base_line = line.split(" # score=")[0]
        else:
            base_line = line
        new_lines.append(f"{base_line}  # score={score:.2f}")

    # كتابة الخطة المعدّلة في ملف جديد ثم استبدال الأصلي
    PLAN_SCORED_FILE.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    PLAN_FILE.write_text("\n".join(new_lines) + "\n", encoding="utf-8")

    # حفظ تقرير درجات العوامل
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    SCORES_JSON.write_text(json.dumps(scores_dump, ensure_ascii=False, indent=2), encoding="utf-8")

    print("✅ تم تحديث الخطة بناءً على KPS/skills/feedback")
    print(f"   - الخطة النهائية: {PLAN_FILE}")
    print(f"   - تقرير الدرجات:  {SCORES_JSON}")


def main() -> None:
    compute_scores_for_plan()


if __name__ == "__main__":
    main()
