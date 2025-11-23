# حالة خطة HyperFFactory (Plan Status)

تاريخ آخر تحديث: {{UPDATE_MANUALLY}}

## المرحلة 1 – التوحيد الأساسي

- [x] إنشاء المصنع الموحّد `/root/HyperFFactory`.
- [x] استيراد تقارير وسكربتات من `/opt` إلى HyperFFactory (imported / reports).
- [x] توحيد قاعدة بيانات SmartFriend في مسار واحد داخل `/opt/smartfriend-suite`.
- [x] إنشاء مركز صحّة موحّد:
  - سكربت `bin/hf_health_smartfriend.sh`
  - سكربت `bin/hf_health_ffactory.sh`
  - سكربت تجميعي `bin/hf_health_all.sh`
- [ ] سكربت حراسة كامل لكل الأوامر لمنع التشغيل من خارج الهيكل الموحّد (قادم).
- [ ] تصنيف السكربتات المجمّعة (منتج / تجريبي / نظام).

## المرحلة 2 – الدمج والتكامل

- [ ] تعريف API موحّد بين HyperFFactory و SmartFriend.
- [ ] تعريف قناة تكامل رسمية مع FFactory (AI / ASR / LLM).
- [ ] توحيد سياسة النسخ الاحتياطي بين HyperFFactory + SmartFriend + FFactory.

## المرحلة 3 – التحسين والجودة

- [ ] تعريف KPIs رسمية (زمن استجابة، توافر الخدمات، صحة الـ Stack).
- [ ] سكربت فحص دوري للـ KPIs وتوليد تقارير JSON + تقارير نصية.
- [ ] لوحة تحكم موحّدة لعرض الحالة (CLI / Telegram / Web).

> المرجع التنفيذي الوحيد: هذا السيرفر + هذا الهيكل الموحّد.  
> أي تشغيل خارج /root/HyperFFactory أو الأنظمة المصرّح بها يعتبر مخالفة يجب إصلاحها.
