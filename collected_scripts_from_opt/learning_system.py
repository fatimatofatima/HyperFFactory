# MyDeepseek/learning_system.py
import json
import random

class LearningSystem:
    def __init__(self):
        self.lessons = self.load_lessons()
        self.user_progress = {}
    
    def load_lessons(self):
        """تحميل الدروس التعليمية"""
        return {
            "python_basics": {
                "title": "🐍 أساسيات بايثون",
                "lessons": [
                    {
                        "id": 1,
                        "title": "المتغيرات والأنواع",
                        "content": "المتغيرات تخزن البيانات. في بايثون:\\n\\n```python\\nname = 'أحمد'  # نص\\nage = 25       # رقم\\nis_student = True  # منطقي\\n```",
                        "exercise": "أنشئ متغيرين: واحد للاسم والآخر للعمر"
                    },
                    {
                        "id": 2, 
                        "title": "الجمل الشرطية",
                        "content": "if تستخدم لاتخاذ القرارات:\\n\\n```python\\nage = 18\\nif age >= 18:\\n    print('بالغ')\\nelse:\\n    print('قاصر')\\n```",
                        "exercise": "اكتب برنامج يتحقق إذا كان الرقم موجب أم سالب"
                    },
                    {
                        "id": 3,
                        "title": "الحلقات التكرارية",
                        "content": "for تستخدم للتكرار:\\n\\n```python\\nfor i in range(5):\\n    print('مرحباً')\\n```",
                        "exercise": "اطبع الأرقام من 1 إلى 10 باستخدام for"
                    }
                ]
            },
            "web_basics": {
                "title": "🌐 أساسيات الويب",
                "lessons": [
                    {
                        "id": 1,
                        "title": "HTML الأساسية",
                        "content": "HTML لبناء هيكل الصفحة:\\n\\n```html\\n<!DOCTYPE html>\\n<html>\\n<head>\\n    <title>صفحتي</title>\\n</head>\\n<body>\\n    <h1>مرحباً!</h1>\\n</body>\\n</html>\\n```",
                        "exercise": "أنشئ صفحة HTML ب标题 وعنوان"
                    }
                ]
            }
        }
    
    def get_lesson(self, course, lesson_id):
        """الحصول على درس محدد"""
        course_data = self.lessons.get(course)
        if not course_data:
            return None
        
        for lesson in course_data["lessons"]:
            if lesson["id"] == lesson_id:
                return lesson
        
        return None
    
    def get_course_progress(self, user_id, course):
        """الحصول على تقدم المستخدم في دورة"""
        if user_id not in self.user_progress:
            self.user_progress[user_id] = {}
        
        return self.user_progress[user_id].get(course, {"completed_lessons": [], "current_lesson": 1})
    
    def complete_lesson(self, user_id, course, lesson_id):
        """إكمال درس"""
        if user_id not in self.user_progress:
            self.user_progress[user_id] = {}
        
        if course not in self.user_progress[user_id]:
            self.user_progress[user_id][course] = {"completed_lessons": [], "current_lesson": 1}
        
        if lesson_id not in self.user_progress[user_id][course]["completed_lessons"]:
            self.user_progress[user_id][course]["completed_lessons"].append(lesson_id)
            self.user_progress[user_id][course]["current_lesson"] = lesson_id + 1
        
        return True
    
    def get_next_lesson(self, user_id, course):
        """الحصول على الدرس التالي"""
        progress = self.get_course_progress(user_id, course)
        next_lesson_id = progress["current_lesson"]
        return self.get_lesson(course, next_lesson_id)

# إنشاء نظام التعلم
learning_system = LearningSystem()
