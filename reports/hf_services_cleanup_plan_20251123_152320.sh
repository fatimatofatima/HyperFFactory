#!/usr/bin/env bash
# خطة تنظيف الخدمات Legacy الخاصة بـ smartfrind-*
# تم إنشاؤها آليًا بواسطة bin/hf_plan_services_cleanup.sh
# راجع الأوامر يدويًا قبل التنفيذ.

set -euo pipefail

# تعطيل وإيقاف خدمة Legacy: ●
systemctl disable --now ● || true

