# MyDeepseek/ai_engine.py
import logging
from dataclasses import dataclass
import random

logger = logging.getLogger(__name__)

@dataclass
class OwnerProfile:
    name: str = "المبرمج"
    style: str = (
        "مساعد ذكاء اصطناعي يمثل مبرمج عربي خبير. "
        "الردود قصيرة، مباشرة، بدون حشو. "
        "يستخدم مصطلحات الأعمال والتقنية عند الحاجة. "
        "يفكر بطريقة إبداعية غير تقليدية لكن منطقية. "
        "يشرح الحلول البرمجية بوضوح وبخطوات عملية."
    )

class AIEngine:
    def __init__(self):
        self.profile = OwnerProfile()
        self.setup_responses()

    def setup_responses(self):
        """إعداد نماذج الردود بأسلوب المبرمج الخبير"""
        self.technical_responses = [
            "كمبرمج خبير، أرى الحل كالتالي:\n{analysis}\nالتنفيذ: {solution}",
            "من وجهة نظر تقنية:\n{analysis}\nالحل الأمثل: {solution}",
            "تحليل سريع:\n{analysis}\nالكود النظيف: {solution}"
        ]
        
        self.creative_responses = [
            "تفكير خارج الصندوق:\n{idea}\nالتنفيذ العملي: {implementation}",
            "رؤية إبداعية للمشكلة:\n{perspective}\nالخطوات: {steps}",
            "منظور مختلف:\n{insight}\nالحل: {solution}"
        ]

    async def reply_as_owner(self, user_id: str, user_name: str, message: str) -> str:
        """
        المحرك الرئيسي - يمثل شخصيتي كمبرمج خبير
        """
        logger.info(f"👤 {user_name} ({user_id}): {message}")

        message_lower = message.strip().lower()
        
        # تحليل نوع الرسالة وتوليد رد مناسب
        if any(word in message_lower for word in ["python", "بايثون", "كود", "code", "برمجة"]):
            return self._handle_programming_query(message, user_name)
        
        elif any(word in message_lower for word in ["خطأ", "error", "مشكلة", "problem", "bug"]):
            return self._handle_error_query(message, user_name)
        
        elif any(word in message_lower for word in ["مشروع", "project", "تطبيق", "app", "موقع", "website"]):
            return self._handle_project_query(message, user_name)
        
        elif any(word in message_lower for word in ["كيف", "how", "طريقة", "method", "خطوات"]):
            return self._handle_howto_query(message, user_name)
        
        else:
            return self._handle_general_query(message, user_name)

    def _handle_programming_query(self, message: str, user_name: str) -> str:
        """معالجة الاستفسارات البرمجية"""
        responses = [
            f"{user_name}، رؤية تقنية سريعة:\n\n"
            "🔍 **التشخيص**: سأحتاج رؤية الكود أو الوظيفة المطلوبة\n"
            "💡 **الحل**: بناءً على خبرتي، أفضل ممارسات Production:\n"
            "- هيكلة نظيفة (Clean Architecture)\n" 
            "- معالجة أخطاء شاملة\n"
            "- توثيق واضح\n"
            "📝 أرسل الكود أو المتطلبات وسأبني لك الحل الأمثل.",

            f"{user_name}، كمبرمج خبير:\n\n"
            "التفكير في Scalability من البداية:\n"
            "✅ هيكلة قابلة للتوسع\n"
            "✅ كود قابل للصيانة\n" 
            "✅ أمان وسرعة\n"
            "🛠 حدد المتطلبات الدقيقة وسأقدم خطة تنفيذ عملية."
        ]
        return random.choice(responses)

    def _handle_error_query(self, message: str, user_name: str) -> str:
        """معالجة مشاكل الأخطاء"""
        responses = [
            f"{user_name}، منهجية Debugging الاحترافية:\n\n"
            "1️⃣ **التشخيص الدقيق**: أرسل رسالة الخطأ كاملة\n"
            "2️⃣ **السياق**: الكود المرتبط + البيئة\n" 
            "3️⃣ **التحليل**: سأبحث عن Root Cause\n"
            "4️⃣ **الحل**: Fix نظيف + Preventive measures\n"
            "🔧 هيا نبدأ بالخطوة 1...",

            f"{user_name}، كـ Senior Developer:\n\n"
            "فهم الأخطاء يتطلب:\n"
            "📋 Stack trace كامل\n"
            "🔍 الكود المسبب\n"
            "⚙️ بيئة التشغيل\n"
            "🧠 مع هذه المعلومات، أحلل السبب الجذري وأقدم الحل الأمثل."
        ]
        return random.choice(responses)

    def _handle_project_query(self, message: str, user_name: str) -> str:
        """معالجة استفسارات المشاريع"""
        responses = [
            f"{user_name}، تصميم المشروع كمحترف:\n\n"
            "📊 **التحليل**: الفكرة + الجمهور المستهدف\n"
            "🏗 **الهيكلة**: التقنيات المناسبة + Scalability\n"
            "⚡ **الأداء**: Optimization من البداية\n"
            "🔒 **الأمان**: Best practices\n"
            "💎 اشرح الفكرة وسأصمم لك خطة تنفيذ شاملة.",

            f"{user_name}، منهجية بناء المشاريع:\n\n"
            "🎯 **الهدف التجاري**: ما القيمة المقدمة؟\n" 
            "🛠 **التقنيات**: Tech stack مناسب\n"
            "📈 **قابلية النمو**: هندسة قابلة للتوسع\n"
            "🚀 **خطة التنفيذ**: خطوات عملية واضحة\n"
            "📝 دعنا نبدأ بتحديد الهدف الأساسي..."
        ]
        return random.choice(responses)

    def _handle_howto_query(self, message: str, user_name: str) -> str:
        """معالجة استفسارات 'كيف'"""
        responses = [
            f"{user_name}، الطريقة المحترفة:\n\n"
            "1. فهم المتطلبات بدقة\n"
            "2. تحليل الحلول الممكنة\n" 
            "3. اختيار الأنسب للمشكلة\n"
            "4. تنفيذ خطوة بخطوة\n"
            "5. اختبار وتحسين\n"
            "🔍 ركز على الهدف النهائي وسأرشدك للطريقة المثلى.",

            f"{user_name}، التفكير المنهجي:\n\n"
            "🔎 **الفهم**: ما المشكلة بالضبط؟\n"
            "💭 **التحليل**: كل الخيارات المتاحة\n"
            "🎯 **الاختيار**: الحل الأمثل للموقف\n" 
            "🛠 **التنفيذ**: خطوات عملية واضحة\n"
            "📝 اشرح الهدف وسأضع لك خطة التنفيذ."
        ]
        return random.choice(responses)

    def _handle_general_query(self, message: str, user_name: str) -> str:
        """معالجة الاستفسارات العامة"""
        responses = [
            f"{user_name}، كخبير تقني:\n\n"
            "فهمت طلبك. للوصول لأفضل حل:\n"
            "🎯 حدد الهدف النهائي بوضوح\n" 
            "🛠 اختر التقنيات المناسبة\n"
            "📊 فكر في Scalability من البداية\n"
            "💡 ركز على حل المشكلة الجذرية\n"
            "🚀 اشرح لي احتياجك وسأبني لك الحل العملي.",

            f"{user_name}، المنظور الاستراتيجي:\n\n"
            "كمبرمج خبير، أنظر للمشاكل من زوايا:\n"
            "• الجدوى التقنية\n"
            "• قابلية الصيانة\n" 
            "• الأداء والأمان\n"
            "• تجربة المستخدم\n"
            "📝 ضع الهدف وسأقدم تحليل شامل + خطة تنفيذ."
        ]
        return random.choice(responses)

# كائن جاهز للاستخدام
ai_engine = AIEngine()
