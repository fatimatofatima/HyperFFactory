#!/usr/bin/env python3
"""
النظام الرئيسي الشامل لـ Hyper-Factory - الإصدار النهائي
"""

import os
import sqlite3
import json
from datetime import datetime

class HyperFactorySystem:
    def __init__(self):
        self.knowledge_db = "data/knowledge/knowledge.db"
        self.system_config = "config/system_config.json"
        self.setup_environment()
    
    def setup_environment(self):
        """إعداد بيئة النظام"""
        directories = [
            "scripts", "tools", "data/knowledge", "ai/memory",
            "logs/diagnostics", "reports/diagnostics", "reports/management",
            "reports/ai", "config", "agents"
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
        
        # تكوين النظام
        if not os.path.exists(self.system_config):
            config = {
                "system_name": "Hyper-Factory AI System",
                "version": "2.0.0",
                "created_date": datetime.now().isoformat(),
                "modules": {
                    "crawler": True,
                    "debug_expert": True,
                    "knowledge_base": True,
                    "ai_agents": True,
                    "reporting": True
                },
                "settings": {
                    "max_crawler_depth": 3,
                    "max_pages_per_session": 100,
                    "auto_cleanup": True,
                    "learning_enabled": True
                }
            }
            
            with open(self.system_config, 'w') as f:
                json.dump(config, f, indent=2)
    
    def get_system_status(self):
        """الحصول على حالة النظام الشاملة"""
        print("🔍 فحص حالة النظام الشاملة...")
        
        status = {
            "timestamp": datetime.now().isoformat(),
            "knowledge_base": self.check_knowledge_base(),
            "crawler_system": self.check_crawler_system(),
            "ai_agents": self.check_ai_agents(),
            "file_system": self.check_file_system(),
            "recommendations": []
        }
        
        return status
    
    def check_knowledge_base(self):
        """فحص قاعدة المعرفة"""
        try:
            conn = sqlite3.connect(self.knowledge_db)
            cursor = conn.cursor()
            
            # الجداول
            cursor.execute('SELECT name FROM sqlite_master WHERE type="table"')
            tables = [row[0] for row in cursor.fetchall()]
            
            # إحصائيات web_knowledge
            stats = {}
            if 'web_knowledge' in tables:
                cursor.execute('SELECT COUNT(*) FROM web_knowledge')
                stats['total_records'] = cursor.fetchone()[0]
                
                cursor.execute('SELECT COUNT(DISTINCT url) FROM web_knowledge')
                stats['unique_urls'] = cursor.fetchone()[0]
                
                cursor.execute('SELECT COUNT(DISTINCT category) FROM web_knowledge')
                stats['categories'] = cursor.fetchone()[0]
            
            conn.close()
            
            return {
                "status": "healthy",
                "tables_count": len(tables),
                "stats": stats,
                "tables": tables
            }
            
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    def check_crawler_system(self):
        """فحص نظام الزحف"""
        crawler_files = [
            "scripts/fix_crawler_issues.py",
            "tools/hf_web_spider_optimized.py",
            "tools/hf_smart_crawler.py",
            "tools/hf_crawler_manager.py",
            "tools/clean_knowledge_base.py"
        ]
        
        status = {"status": "healthy", "files": {}}
        
        for file in crawler_files:
            status["files"][file] = os.path.exists(file)
            if not os.path.exists(file):
                status["status"] = "warning"
        
        return status
    
    def check_ai_agents(self):
        """فحص العوامل الذكية"""
        agent_files = [
            "tools/hf_debug_expert_final.py",
            "agents/debug_expert/__init__.py",
            "agents/system_architect/__init__.py"
        ]
        
        status = {"status": "healthy", "agents": {}}
        
        for file in agent_files:
            exists = os.path.exists(file)
            status["agents"][file] = exists
            if not exists and "debug_expert" in file:
                status["status"] = "warning"
        
        return status
    
    def check_file_system(self):
        """فحص نظام الملفات"""
        essential_dirs = [
            "data/knowledge", "ai/memory", "reports", 
            "logs", "scripts", "tools", "config"
        ]
        
        status = {"status": "healthy", "directories": {}}
        
        for directory in essential_dirs:
            exists = os.path.exists(directory)
            status["directories"][directory] = exists
            if not exists:
                status["status"] = "error"
        
        return status
    
    def generate_system_report(self):
        """توليد تقرير النظام الشامل"""
        print("📊 توليد تقرير النظام الشامل...")
        
        status = self.get_system_status()
        
        # حفظ التقرير
        report_file = f"reports/management/system_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        with open(report_file, 'w') as f:
            json.dump(status, f, indent=2)
        
        # عرض التقرير
        self.display_system_report(status, report_file)
        
        return status
    
    def display_system_report(self, status, report_file):
        """عرض تقرير النظام"""
        print(f"""
🚀 Hyper-Factory System Report
==============================

📅 التقرير: {status['timestamp']}
📄 الملف: {report_file}

📊 قاعدة المعرفة:
   ✅ الحالة: {status['knowledge_base']['status']}
   📁 الجداول: {status['knowledge_base']['tables_count']}
   📊 السجلات: {status['knowledge_base']['stats'].get('total_records', 'N/A')}
   🌐 الروابط: {status['knowledge_base']['stats'].get('unique_urls', 'N/A')}
   🏷️  الفئات: {status['knowledge_base']['stats'].get('categories', 'N/A')}

🕷️  نظام الزحف:
   ✅ الحالة: {status['crawler_system']['status']}
   📁 الملفات: {sum(status['crawler_system']['files'].values())}/{len(status['crawler_system']['files'])}

🤖 العوامل الذكية:
   ✅ الحالة: {status['ai_agents']['status']}
   📁 الملفات: {sum(status['ai_agents']['agents'].values())}/{len(status['ai_agents']['agents'])}

💾 نظام الملفات:
   ✅ الحالة: {status['file_system']['status']}
   📁 المجلدات: {sum(status['file_system']['directories'].values())}/{len(status['file_system']['directories'])}

🎯 التوصيات:
   - استخدم نظام الزحف المحسن للزحف الآمن
   - راجع تقارير الأداء بانتظام
   - حافظ على تحديث قاعدة المعرفة
        """)
    
    def show_main_menu(self):
        """عرض القائمة الرئيسية"""
        print("""
🏭 Hyper-Factory Master System
===============================

🔧 الأدوات الأساسية:
   1. 📊 عرض تقرير النظام
   2. 🕷️  إدارة الزواحف
   3. 🧠 العوامل الذكية
   4. 📁 إدارة المعرفة
   5. 🛠️  صيانة النظام
   0. 🚪 خروج

💡 اختر الخيار المناسب:
        """)
    
    def run_crawler_manager(self):
        """تشغيل مدير الزواحف"""
        import subprocess
        print("🚀 تشغيل مدير الزواحف...")
        subprocess.run(["python3", "tools/hf_crawler_manager.py"])
    
    def run_system_maintenance(self):
        """تشغيل صيانة النظام"""
        import subprocess
        print("🔧 تشغيل صيانة النظام...")
        
        tasks = [
            ["python3", "scripts/fix_crawler_issues.py"],
            ["python3", "tools/clean_knowledge_base.py"],
            ["python3", "tools/hf_smart_crawler.py"]
        ]
        
        for task in tasks:
            try:
                print(f"⚡ تشغيل: {' '.join(task)}")
                result = subprocess.run(task, capture_output=True, text=True)
                if result.returncode == 0:
                    print("✅ اكتمل بنجاح")
                else:
                    print(f"⚠️  اكتمل مع تحذيرات: {result.stderr}")
            except Exception as e:
                print(f"❌ خطأ: {e}")

if __name__ == "__main__":
    system = HyperFactorySystem()
    
    while True:
        system.show_main_menu()
        choice = input("اختر الخيار (0-5): ").strip()
        
        if choice == "0":
            print("👋 مع السلامة!")
            break
        elif choice == "1":
            system.generate_system_report()
        elif choice == "2":
            system.run_crawler_manager()
        elif choice == "3":
            print("🤖 تشغيل العوامل الذكية...")
            # يمكن إضافة تشغيل العوامل الذكية هنا
        elif choice == "4":
            print("📁 إدارة قاعدة المعرفة...")
            import subprocess
            subprocess.run(["python3", "tools/clean_knowledge_base.py"])
        elif choice == "5":
            system.run_system_maintenance()
        else:
            print("❌ خيار غير صحيح")
        
        input("\n↵ اضغط Enter للمتابعة...")
