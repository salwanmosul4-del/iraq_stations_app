import 'package:flutter/foundation.dart';

/// اسم التطبيق الظاهر داخل الواجهة. غيّره هنا (وفي AndroidManifest.xml) إذا أردت اسماً آخر.
const String kAppName = 'محطات العراق';

// ---------------- AdMob ----------------
const String kBannerAdUnitId = 'ca-app-pub-7520136213524222/5888302175';
const String kTestBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// أثناء التطوير (debug) تُستخدم إعلانات تجريبية حتى لا يتضرر حساب AdMob.
String get bannerAdUnitId => kDebugMode ? kTestBannerAdUnitId : kBannerAdUnitId;

// ---------------- قواعد التطبيق ----------------
/// حدود العراق التقريبية (تُستخدم عند إضافة محطة جديدة).
/// إذا غيّرتها غيّر نفس الأرقام في firebase/firestore.rules.
const double kMinLat = 28.9;
const double kMaxLat = 37.5;
const double kMinLng = 38.7;
const double kMaxLng = 48.8;

bool isInIraq(double lat, double lng) =>
    lat > kMinLat && lat < kMaxLat && lng > kMinLng && lng < kMaxLng;

/// أقصى مسافة بين المستخدم والمحطة للسماح له بإرسال بلاغ عنها.
const double kMaxReportDistanceMeters = 1500;

/// نصف القطر الذي تُعتبر فيه المحطة الجديدة مكررة.
const double kDuplicateRadiusMeters = 60;

/// المدة الدنيا بين بلاغين من نفس الجهاز عن نفس المحطة.
const Duration kReportCooldown = Duration(minutes: 10);

/// بعد هذه المدة تُعتبر آخر حالة قديمة وغير مؤكدة.
const Duration kStaleAfter = Duration(hours: 3);

/// يُعرض عدد السيارات في الطابور فقط إذا كان البلاغ أحدث من هذه المدة.
const Duration kQueueFreshFor = Duration(minutes: 90);

/// تقدير زمن الانتظار = عدد السيارات × (دقائق لكل سيارة) — أدنى وأعلى تقدير.
/// هذه أرقام تقديرية من عندي؛ عدّلها بحسب الواقع.
const double kWaitMinutesPerCarLow = 1.0;
const double kWaitMinutesPerCarHigh = 1.8;

/// إسناد بيانات OpenStreetMap في شاشة الإعدادات (اتركه true إن استوردت المحطات منها).
const bool kShowOsmCredit = true;

// ---------------- الخريطة ----------------
/// مصدر بلاطات الخريطة. الافتراضي خادم OpenStreetMap العام، ويناسب التجربة والاستخدام الخفيف فقط
/// (سياسة OSM تمنع الاستخدام الكثيف: https://operations.osmfoundation.org/policies/tiles/).
/// قبل النشر الواسع استبدله بمزوّد بخدمة مناسبة (MapTiler / Stadia / Thunderforest ...) مع مفتاحه،
/// مثل: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=YOUR_KEY'
const String kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// أقصى عدد علامات تُرسم على الخريطة دفعة واحدة (للحفاظ على سلاسة الأجهزة الضعيفة).
const int kMaxMapMarkers = 300;
