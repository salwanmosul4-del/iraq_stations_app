import 'dart:math' as math;

/// محافظة مع إحداثيات مركزها التقريبية (تُستخدم لتوسيط الخريطة واقتراح المحافظة الأقرب).
/// الأسماء يجب أن تطابق تماماً الأسماء في tools/import_osm_stations.py وفي firebase/firestore.rules.
class Governorate {
  const Governorate(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;
}

const List<Governorate> kGovernorates = [
  Governorate('بغداد', 33.3152, 44.3661),
  Governorate('نينوى', 36.3400, 43.1300),
  Governorate('البصرة', 30.5081, 47.7835),
  Governorate('أربيل', 36.1911, 44.0092),
  Governorate('السليمانية', 35.5613, 45.4308),
  Governorate('دهوك', 36.8679, 42.9885),
  Governorate('كركوك', 35.4681, 44.3922),
  Governorate('الأنبار', 33.4258, 43.3000),
  Governorate('بابل', 32.4637, 44.4192),
  Governorate('كربلاء', 32.6160, 44.0249),
  Governorate('النجف', 32.0000, 44.3360),
  Governorate('القادسية', 31.9889, 44.9250),
  Governorate('المثنى', 31.3094, 45.2800),
  Governorate('ذي قار', 31.0439, 46.2575),
  Governorate('ميسان', 31.8358, 47.1442),
  Governorate('واسط', 32.5000, 45.8200),
  Governorate('ديالى', 33.7500, 44.6500),
  Governorate('صلاح الدين', 34.6000, 43.6800),
];

Governorate? governorateByName(String name) {
  for (final g in kGovernorates) {
    if (g.name == name) return g;
  }
  return null;
}

/// المحافظة الأقرب لنقطة (تقريبية: قد تخطئ قرب الحدود بين محافظتين، ويستطيع المستخدم تغييرها).
Governorate nearestGovernorate(double lat, double lng) {
  Governorate best = kGovernorates.first;
  var bestD = double.infinity;
  for (final g in kGovernorates) {
    final dy = g.lat - lat;
    final dx = (g.lng - lng) * math.cos(lat * math.pi / 180);
    final d = dx * dx + dy * dy;
    if (d < bestD) {
      bestD = d;
      best = g;
    }
  }
  return best;
}
