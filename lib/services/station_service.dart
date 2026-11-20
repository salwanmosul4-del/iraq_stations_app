import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/station.dart';

class StationService {
  StationService._();
  static final StationService instance = StationService._();

  static const _timeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('stations');

  /// [governorate] = null لتحميل كل محطات العراق.
  Stream<List<Station>> watchStations({String? governorate}) {
    Query<Map<String, dynamic>> q = _col;
    if (governorate != null) {
      q = q.where('governorate', isEqualTo: governorate);
    }
    return q
        .limit(4000)
        .snapshots()
        .map((snap) => snap.docs.map(Station.fromDoc).toList());
  }

  String _cooldownKey(String stationId) => 'last_report_$stationId';

  /// الوقت المتبقي قبل أن يستطيع هذا الجهاز إرسال بلاغ جديد عن المحطة، أو null.
  Future<Duration?> cooldownLeft(String stationId) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_cooldownKey(stationId));
    if (last == null) return null;
    final elapsed =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    final left = kReportCooldown - elapsed;
    return left.isNegative ? null : left;
  }

  Future<void> report({
    required Station station,
    required StationStatus status,
    int? queueCars,
    required Set<FuelType> fuels,
  }) async {
    final open = status == StationStatus.open;
    await _col.doc(station.id).update({
      'status': status.name,
      'queueCars': open ? queueCars : null,
      'fuels': open ? fuels.map((f) => f.key).toList() : <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'reportsCount': FieldValue.increment(1),
    }).timeout(_timeout);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _cooldownKey(station.id), DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> addStation({
    required String name,
    required String area,
    required String governorate,
    required double lat,
    required double lng,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('المستخدم غير مسجّل الدخول');

    await _col.add({
      'name': name,
      'area': area,
      'governorate': governorate,
      'lat': lat,
      'lng': lng,
      'status': StationStatus.unknown.name,
      'queueCars': null,
      'fuels': <String>[],
      'reportsCount': 0,
      'source': 'user',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }
}
