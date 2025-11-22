#!/usr/bin/env python3
"""
سكربت ETL لتحميل Smart Scans إلى قاعدة المعرفة
"""
import sqlite3
import json
import os
import re
from datetime import datetime
from pathlib import Path

class SmartScansETL:
    def __init__(self, hf_root):
        self.hf_root = Path(hf_root)
        self.db_path = self.hf_root / "data" / "knowledge" / "knowledge.db"
        self.scans_dir = self.hf_root / "reports" / "smart"
        
    def extract_scan_info(self, file_path):
        """استخراج معلومات من اسم الملف"""
        filename = file_path.name
        pattern = r"smart_scan_(\d{8})_(\d{6})\.json"
        match = re.match(pattern, filename)
        
        if match:
            date_str = match.group(1)
            time_str = match.group(2)
            scan_timestamp = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]} {time_str[:2]}:{time_str[2:4]}:{time_str[4:6]}"
            return scan_timestamp
        return None
    
    def analyze_scan_content(self, content):
        """تحليل محتوى الـ scan"""
        try:
            data = json.loads(content)
            
            # حساب الإحصائيات الأساسية
            stats = {
                'components_total': 0,
                'components_ok': 0,
                'components_missing': 0,
                'components_warning': 0,
                'critical_issues': 0,
                'maturity_score': 0.0
            }
            
            # تحليل بسيط للمحتوى (يمكن تطويره)
            if 'components' in data:
                stats['components_total'] = len(data['components'])
                stats['components_ok'] = sum(1 for c in data['components'] if c.get('status') == 'ok')
                stats['components_missing'] = sum(1 for c in data['components'] if c.get('status') == 'missing')
                stats['components_warning'] = sum(1 for c in data['components'] if c.get('status') == 'warning')
            
            if 'summary' in data:
                stats['maturity_score'] = data['summary'].get('maturity_score', 0.0)
                stats['critical_issues'] = data['summary'].get('critical_issues', 0)
            
            return stats
            
        except json.JSONDecodeError:
            return None
    
    def process_smart_scans(self):
        """معالجة جميع ملفات Smart Scans"""
        if not self.scans_dir.exists():
            print("❌ مجلد Smart Scans غير موجود")
            return
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        processed = 0
        for scan_file in self.scans_dir.glob("smart_scan_*.json"):
            try:
                # استخراج المعلومات من اسم الملف
                scan_timestamp = self.extract_scan_info(scan_file)
                if not scan_timestamp:
                    continue
                
                # قراءة المحتوى
                content = scan_file.read_text(encoding='utf-8')
                stats = self.analyze_scan_content(content)
                
                if stats:
                    # إدخال في قاعدة البيانات
                    cursor.execute('''
                    INSERT OR REPLACE INTO smart_scans 
                    (scan_id, scan_timestamp, scan_type, components_total, components_ok, 
                     components_missing, components_warning, maturity_score, critical_issues, raw_json_path)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        scan_file.stem,  # smart_scan_20251121_100259
                        scan_timestamp,
                        'structure',  # يمكن تحديد النوع من المحتوى
                        stats['components_total'],
                        stats['components_ok'],
                        stats['components_missing'],
                        stats['components_warning'],
                        stats['maturity_score'],
                        stats['critical_issues'],
                        str(scan_file.relative_to(self.hf_root))
                    ))
                    
                    processed += 1
                    print(f"✅ معالجة: {scan_file.name}")
                    
            except Exception as e:
                print(f"❌ خطأ في معالجة {scan_file.name}: {e}")
        
        conn.commit()
        conn.close()
        print(f"🎯 تم معالجة {processed} ملف Smart Scan")

if __name__ == "__main__":
    etl = SmartScansETL("/root/hyper-factory")
    etl.process_smart_scans()
