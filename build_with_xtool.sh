#!/usr/bin/env bash
# ==============================================================
# Script to build, sign, and deploy AirGapReceiver with xtool
# ==============================================================
set -e

echo "=== فحص وتثبيت xtool ==="
if ! command -v xtool &> /dev/null; then
    echo "xtool غير مثبت، جاري التحميل والتثبيت التلقائي..."
    curl -L https://xtool.sh/install.sh | bash
    export PATH="$HOME/.xtool/bin:$PATH"
fi

echo "إصدار xtool المثبت:"
xtool --version

echo ""
echo "=== الخطوة 1: تسجيل الدخول بحساب Apple ID للمصادقة وتوقيع التطبيق ==="
echo "إذا لم تكن قد سجلت الدخول مسبقاً، سيطلب منك معرف Apple ID الخاص بك:"
xtool auth login || true

echo ""
echo "=== الخطوة 2: توصيل هاتف iPhone عبر كابل USB ==="
echo "يرجى التأكد من توصيل جهاز iPhone بالكمبيوتر وإلغاء قفل الشاشة (والضغط على 'الوثوق بهذا الكمبيوتر')."
echo ""

read -p "اضغط Enter عندما يكون الهاتف متصلاً وجاهزاً..."

echo "=== الخطوة 3: بناء وتوقيع وتثبيت التطبيق على جهاز iPhone مباشرة ==="
xtool dev
