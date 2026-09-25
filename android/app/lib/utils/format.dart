import '../config.dart';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} م';
  return '${(meters / 1000).toStringAsFixed(1)} كم';
}

String timeAgo(DateTime time) {
  final d = DateTime.now().difference(time);
  if (d.inMinutes < 1) return 'قبل لحظات';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
  return 'قبل ${d.inDays} يوم';
}

/// تقدير زمن الانتظار من عدد السيارات (تقريب لأقرب 5 دقائق).
String formatWaitRange(int cars) {
  int r5(double v) => (v / 5).round() * 5;
  final lo = r5(cars * kWaitMinutesPerCarLow);
  final hi = r5(cars * kWaitMinutesPerCarHigh);
  if (hi <= 0) return 'بدون انتظار';
  return lo == hi ? '$lo دقيقة' : '$lo إلى $hi دقيقة';
}
