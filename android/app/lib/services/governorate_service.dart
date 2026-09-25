import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/governorates.dart';

/// قيمة خاصة تعني "كل العراق".
const String kAllIraq = 'ALL';

/// المحافظة التي يعرض التطبيق محطاتها (محفوظة على الجهاز).
/// تحميل محافظة واحدة يقلل عدد القراءات من Firestore بدل تحميل كل محطات العراق.
class GovernorateService extends ChangeNotifier {
  GovernorateService._();
  static final GovernorateService instance = GovernorateService._();

  static const _key = 'selected_governorate';
  String? _value;

  /// null = لم يختر المستخدم بعد.
  String? get value => _value;
  bool get isChosen => _value != null;
  bool get isAll => _value == kAllIraq;

  /// الاسم المستخدم في استعلام Firestore، أو null لتحميل كل العراق.
  String? get queryValue => (_value == null || _value == kAllIraq) ? null : _value;

  Governorate? get governorate {
    final q = queryValue;
    return q == null ? null : governorateByName(q);
  }

  String get label => _value == null ? 'اختر المحافظة' : (isAll ? 'كل العراق' : _value!);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == kAllIraq || (saved != null && governorateByName(saved) != null)) {
      _value = saved;
    }
    notifyListeners();
  }

  Future<void> set(String value) async {
    if (_value == value) return;
    _value = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }
}
