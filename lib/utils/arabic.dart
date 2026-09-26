/// توحيد النص العربي للبحث (إزالة التشكيل وتوحيد الألف والتاء المربوطة والياء).
String normalizeArabic(String input) {
  return input
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase()
      .trim();
}
