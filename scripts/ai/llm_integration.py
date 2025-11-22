#!/usr/bin/env python3
import os
import sys
import yaml
from pathlib import Path

class HyperFFactoryAI:
    def __init__(self):
        self.root_dir = Path(__file__).parent.parent.parent
        self.config_dir = self.root_dir / "config"
        
    def load_agent_config(self, agent_id):
        """تحميل إعدادات الـ Agent من agents.yaml"""
        agents_file = self.config_dir / "agents.yaml"
        with open(agents_file, 'r', encoding='utf-8') as f:
            agents_data = yaml.safe_load(f)
        
        for agent in agents_data.get('agents', []):
            if agent['id'] == agent_id:
                return agent
        return None
    
    def load_prompt(self, prompt_file):
        """تحميل محتوى الـ Prompt"""
        prompt_path = self.root_dir / prompt_file
        if prompt_path.exists():
            with open(prompt_path, 'r', encoding='utf-8') as f:
                return f.read()
        return None
    
    def run_agent(self, agent_id, user_input=""):
        """تشغيل الـ Agent مع المدخلات"""
        agent_config = self.load_agent_config(agent_id)
        if not agent_config:
            print(f"❌ Agent {agent_id} not found")
            return
        
        prompt_content = self.load_prompt(agent_config['prompt_file'])
        if not prompt_content:
            print(f"❌ Prompt file not found: {agent_config['prompt_file']}")
            return
        
        print(f"🤖 [{agent_config['name']}]")
        print(f"📁 Prompt: {agent_config['prompt_file']}")
        print("─" * 50)
        
        # بناء الـ Prompt النهائي
        full_prompt = f"""
{prompt_content}

المهمة الحالية:
{user_input}

الرجاء تقديم المساعدة:
"""
        print(full_prompt)
        print("─" * 50)
        print("🚀 جاهز للإرسال إلى LLM...")
        
        return full_prompt

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 llm_integration.py <agent_id> [user_input]")
        sys.exit(1)
    
    agent_id = sys.argv[1]
    user_input = sys.argv[2] if len(sys.argv) > 2 else "طلب مساعدة عامة"
    
    ai_system = HyperFFactoryAI()
    ai_system.run_agent(agent_id, user_input)
