# MyDeepseek/learning_commands.py
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes, CallbackQueryHandler
from learning_system import learning_system

class LearningCommands:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    async def start_learning(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """بدء التعلم"""
        keyboard = [
            [InlineKeyboardButton("🐍 بايثون للمبتدئين", callback_data="course_python_basics")],
            [InlineKeyboardButton("🌐 أساسيات الويب", callback_data="course_web_basics")],
            [InlineKeyboardButton("🤖 الذكاء الاصطناعي", callback_data="course_ai")],
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await update.message.reply_text(
            "🎓 **اختر الدورة التعليمية:**\n\n"
            "اختر المجال الذي تريد تعلمه:",
            reply_markup=reply_markup
        )
    
    async def handle_course_selection(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """معالجة اختيار الدورة"""
        query = update.callback_query
        await query.answer()
        
        user_id = str(query.from_user.id)
        callback_data = query.data
        
        if callback_data.startswith("course_"):
            course_id = callback_data.replace("course_", "")
            course = learning_system.lessons.get(course_id)
            
            if course:
                # بدء الدرس الأول
                next_lesson = learning_system.get_next_lesson(user_id, course_id)
                
                if next_lesson:
                    keyboard = [
                        [InlineKeyboardButton("✅ إكمال الدرس", callback_data=f"complete_{course_id}_{next_lesson['id']}")],
                        [InlineKeyboardButton("📚 الدرس التالي", callback_data=f"next_{course_id}")],
                    ]
                    reply_markup = InlineKeyboardMarkup(keyboard)
                    
                    await query.edit_message_text(
                        f"🎯 **{course['title']}**\n\n"
                        f"📖 **{next_lesson['title']}**\n\n"
                        f"{next_lesson['content']}\n\n"
                        f"💡 **التمرين:** {next_lesson['exercise']}",
                        reply_markup=reply_markup
                    )
                else:
                    await query.edit_message_text("🎉 مبروك! أكملت جميع دروس هذه الدورة!")
            else:
                await query.edit_message_text("❌ الدورة غير متوفرة بعد")
        
        elif callback_data.startswith("complete_"):
            # إكمال درس
            _, course_id, lesson_id = callback_data.split("_")
            lesson_id = int(lesson_id)
            
            learning_system.complete_lesson(user_id, course_id, lesson_id)
            
            keyboard = [
                [InlineKeyboardButton("📚 الدرس التالي", callback_data=f"next_{course_id}")],
                [InlineKeyboardButton("🏠 القائمة الرئيسية", callback_data="main_menu")],
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                "✅ **أحسنت! أكملت الدرس بنجاح!**\n\n"
                "هل تريد الانتقال للدرس التالي؟",
                reply_markup=reply_markup
            )
        
        elif callback_data.startswith("next_"):
            # الدرس التالي
            course_id = callback_data.replace("next_", "")
            next_lesson = learning_system.get_next_lesson(user_id, course_id)
            
            if next_lesson:
                keyboard = [
                    [InlineKeyboardButton("✅ إكمال الدرس", callback_data=f"complete_{course_id}_{next_lesson['id']}")],
                    [InlineKeyboardButton("📚 الدرس التالي", callback_data=f"next_{course_id}")],
                ]
                reply_markup = InlineKeyboardMarkup(keyboard)
                
                await query.edit_message_text(
                    f"📖 **{next_lesson['title']}**\n\n"
                    f"{next_lesson['content']}\n\n"
                    f"💡 **التمرين:** {next_lesson['exercise']}",
                    reply_markup=reply_markup
                )
            else:
                await query.edit_message_text("🎉 مبروك! أكملت جميع دروس هذه الدورة!")
        
        elif callback_data == "main_menu":
            # العودة للقائمة الرئيسية
            keyboard = [
                [InlineKeyboardButton("🐍 بايثون للمبتدئين", callback_data="course_python_basics")],
                [InlineKeyboardButton("🌐 أساسيات الويب", callback_data="course_web_basics")],
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                "🎓 **اختر الدورة التعليمية:**",
                reply_markup=reply_markup
            )

# إنشاء أوامر التعلم
learning_cmds = LearningCommands()
