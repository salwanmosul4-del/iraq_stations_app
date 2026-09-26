import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';

enum StationStatus { open, closed, unknown }

extension StationStatusX on StationStatus {
  String get label => switch (this) {
        StationStatus.open => 'مفتوحة',
        StationStatus.closed => 'مغلقة',
        StationStatus.unknown => 'غير مؤكدة',
      };

  Color get color => switch (this) {
        StationStatus.open => const Color(0xFF15803D),
        StationStatus.closed => const Color(0xFFB91C1C),
        StationStatus.unknown => const Color(0xFF9CA3AF),
      };

  IconData get icon => switch (this) {
        StationStatus.open => Icons.check,
        StationStatus.closed => Icons.close,
        StationStatus.unknown => Icons.help_outline,
      };

  static StationStatus fromKey(String? key) => StationStatus.values
      .firstWhere((s) => s.name == key, orElse: () => StationStatus.unknown);
}

enum FuelType { regular, premium, superFuel }

extension FuelTypeX on FuelType {
  /// المفتاح المخزَّن في Firestore.
  String get key => switch (this) {
        FuelType.regular => 'regular',
        FuelType.premium => 'premium',
        FuelType.superFuel => 'super',
      };

  String get label => switch (this) {
        FuelType.regular => 'عادي',
        FuelType.premium => 'محسّن',
        FuelType.superFuel => 'سوبر',
      };
}

class Station {
  Station({
    required this.id,
    required this.name,
    required this.area,
    required this.governorate,
    required this.lat,
    required this.lng,
    required this.status,
    required this.queueCars,
    required this.fuels,
    required this.updatedAt,
    required this.reportsCount,
  });

  final String id;
  final String name;
  final String area;
  final String governorate;
  final double lat;
  final double lng;
  final StationStatus status;
  final int? queueCars;
  final Set<FuelType> fuels;
  final DateTime? updatedAt;
  final int reportsCount;

  /// تُحسب في الواجهة عند توفر موقع المستخدم.
  double? distanceMeters;

  /// الحالة قديمة إذا لم يصل بلاغ منذ مدة طويلة أو لم يصل أي بلاغ أصلاً.
  bool get isStale {
    final u = updatedAt;
    return status == StationStatus.unknown ||
        u == null ||
        DateTime.now().difference(u) > kStaleAfter;
  }

  /// الحالة التي تُعرض للمستخدم (القديمة تظهر "غير مؤكدة").
  StationStatus get effectiveStatus => isStale ? StationStatus.unknown : status;

  /// هل عدد السيارات في الطابور حديث بما يكفي لعرضه؟
  bool get hasFreshQueue {
    final u = updatedAt;
    return effectiveStatus == StationStatus.open &&
        queueCars != null &&
        u != null &&
        DateTime.now().difference(u) <= kQueueFreshFor;
  }

  bool hasFuel(FuelType f) =>
      effectiveStatus == StationStatus.open && fuels.contains(f);

  String get subtitle => area.isNotEmpty
      ? area
      : (governorate.isNotEmpty ? 'محافظة $governorate' : '');

  factory Station.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final fuels = <FuelType>{};
    for (final e in (data['fuels'] as List? ?? const [])) {
      for (final f in FuelType.values) {
        if (f.key == e) fuels.add(f);
      }
    }

    final name = ((data['name'] as String?) ?? '').trim();
    final ts = data['updatedAt'] as Timestamp?;

    return Station(
      id: doc.id,
      name: name.isEmpty ? 'محطة وقود' : name,
      area: ((data['area'] as String?) ?? '').trim(),
      governorate: ((data['governorate'] as String?) ?? '').trim(),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      status: StationStatusX.fromKey(data['status'] as String?),
      queueCars: (data['queueCars'] as num?)?.toInt(),
      fuels: fuels,
      // يكون الوقت null لحظة الكتابة المحلية قبل وصول وقت الخادم.
      updatedAt:
          ts?.toDate() ?? (doc.metadata.hasPendingWrites ? DateTime.now() : null),
      reportsCount: (data['reportsCount'] as num?)?.toInt() ?? 0,
    );
  }
}
