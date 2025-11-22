#!/usr/bin/env python3
import sys
import os

def run_agent(agent_id, prompt_file):
    print(f"🤖 تشغيل الـ Agent: {agent_id}")
    print(f"📁 Prompt file: {prompt_file}")
    
    if os.path.exists(prompt_file):
        with open(prompt_file, 'r', encoding='utf-8') as f:
            prompt_content = f.read()
        print(f"📝 Prompt content:\n{prompt_content}")
    else:
        print(f"❌ Prompt file not found: {prompt_file}")
    
    print("🚀 جاهز للربط مع LLM...")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 run_agent_python.py <agent_id> <prompt_file>")
        sys.exit(1)
    
    run_agent(sys.argv[1], sys.argv[2])
