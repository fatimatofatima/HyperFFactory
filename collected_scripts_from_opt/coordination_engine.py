#!/usr/bin/env python3
"""
محرك التنسيق المركزي - العقل الموحد
"""
import sqlite3
import json
from datetime import datetime

class UnifiedCoordinationEngine:
    def __init__(self):
        self.db_path = "/root/hyper-factory/data/knowledge/knowledge.db"
    
    def get_available_agents(self):
        """الحصول على العمال المتاحين"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
        SELECT id, name, expertise, status 
        FROM agents 
        WHERE status = 'active'
        ''')
        
        agents = cursor.fetchall()
        conn.close()
        return agents
    
    def assign_task(self, task_type, requirements):
        """توزيع المهام على العمال المناسبين"""
        available_agents = self.get_available_agents()
        
        # منطق بسيط لتوزيع المهام حسب الخبرة
        suitable_agents = []
        for agent in available_agents:
            agent_id, name, expertise, status = agent
            if any(req in expertise for req in requirements):
                suitable_agents.append(agent_id)
        
        return suitable_agents[:3]  # إرجاع أول 3 عمال مناسبين
    
    def log_coordination(self, task_type, assigned_agents):
        """تسجيل عملية التنسيق"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
        INSERT INTO unified_coordination 
        (coordinator_id, task_type, assigned_agents, status)
        VALUES (?, ?, ?, ?)
        ''', (
            'unified_director',
            task_type,
            json.dumps(assigned_agents),
            'assigned'
        ))
        
        conn.commit()
        conn.close()

if __name__ == "__main__":
    engine = UnifiedCoordinationEngine()
    print("🧠 محرك التنسيق المركزي جاهز")
    print(f"👥 العمال المتاحون: {len(engine.get_available_agents())}")
