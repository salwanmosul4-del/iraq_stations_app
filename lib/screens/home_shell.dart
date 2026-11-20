import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../config.dart';
import '../data/governorates.dart';
import '../models/station.dart';
import '../services/governorate_service.dart';
import '../services/location_service.dart';
import '../services/station_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/governorate_picker.dart';
import 'favorites_page.dart';
import 'map_page.dart';
import 'settings_page.dart';
import 'station_sheet.dart';
import 'stations_page.dart';

/// الهيكل الرئيسي: ثلاثة تبويبات (المحطات / المفضلة / الإعدادات) + إعلان + شريط تنقل.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _gov = GovernorateService.instance;

  // اشتراك واحد فقط في Firestore تتشاركه كل التبويبات والخريطة.
  late Stream<List<Station>> _stream = _makeStream();

  /// آخر قائمة محطات (تتابعها صفحة الخريطة).
  final ValueNotifier<List<Station>> _stations =
      ValueNotifier<List<Station>>(const []);

  List<Station> _latest = const [];
  Position? _pos;
  bool _locating = false;
  int _tab = 0;

  Stream<List<Station>> _makeStream() {
    if (!_gov.isChosen) return Stream<List<Station>>.empty();
    return StationService.instance.watchStations(governorate: _gov.queryValue);
  }

  @override
  void initState() {
    super.initState();
    _gov.addListener(_onGovernorateChanged);
    if (_gov.isChosen) {
      _locate();
    } else {
      _initGovernorate();
    }
  }

  @override
  void dispose() {
    _gov.removeListener(_onGovernorateChanged);
    _stations.dispose();
    super.dispose();
  }

  void _onGovernorateChanged() {
    if (!mounted) return;
    setState(() {
      _latest = const [];
      _stream = _makeStream();
    });
  }

  /// أول تشغيل: نقترح أقرب محافظة من موقع المستخدم، وإن تعذّر نسأله.
  Future<void> _initGovernorate() async {
    await _locate();
    if (!mounted || _gov.isChosen) return;
    final p = _pos;
    if (p != null && isInIraq(p.latitude, p.longitude)) {
      await _gov.set(nearestGovernorate(p.latitude, p.longitude).name);
    } else {
      await _pickGovernorate();
    }
  }

  Future<void> _pickGovernorate() async {
    final v = await showGovernoratePicker(context, selected: _gov.value);
    if (v != null) await _gov.set(v);
  }

  void _snack(String message) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final p = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _pos = p ?? _pos;
      _locating = false;
    });
    if (p == null) {
      _snack('تعذّر تحديد موقعك. فعّل GPS وامنح صلاحية الموقع لعرض أقرب المحطات.');
    }
  }

  void _applyDistances(List<Station> stations) {
    final pos = _pos;
    if (pos == null) return;
    for (final s in stations) {
      s.distanceMeters =
          Geolocator.distanceBetween(pos.latitude, pos.longitude, s.lat, s.lng);
    }
  }

  Future<void> _openStation(Station s) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StationSheet(station: s, position: _pos),
    );
  }

  void _openMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapPage(
          stations: _stations,
          position: _pos,
          governorate: _gov.governorate,
        ),
      ),
    );
  }

  Future<void> _addStation() async {
    final p = _pos;
    final initialGov = _gov.queryValue ??
        (p != null ? nearestGovernorate(p.latitude, p.longitude).name : 'بغداد');

    final result = await showDialog<({String name, String area, String governorate})>(
      context: context,
      builder: (_) => _AddStationDialog(initialGovernorate: initialGov),
    );
    if (result == null || !mounted) return;
    if (result.name.length < 2) {
      _snack('اسم المحطة قصير جداً.');
      return;
    }

    _snack('جارٍ تحديد موقعك…');
    final pos = await LocationService.current();
    if (!mounted) return;
    if (pos == null) {
      _snack('تعذّر تحديد موقعك. فعّل GPS وامنح صلاحية الموقع ثم حاول مجدداً.');
      return;
    }
    if (!isInIraq(pos.latitude, pos.longitude)) {
      _snack('موقعك الحالي خارج نطاق العراق.');
      return;
    }
    final near = _latest.where((s) =>
        Geolocator.distanceBetween(pos.latitude, pos.longitude, s.lat, s.lng) <
        kDuplicateRadiusMeters);
    if (near.isNotEmpty) {
      _snack('توجد محطة مسجّلة قريبة جداً من موقعك: ${near.first.name}');
      return;
    }

    try {
      await StationService.instance.addStation(
        name: result.name,
        area: result.area,
        governorate: result.governorate,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _snack('تمت إضافة المحطة. شكراً لك!');
    } catch (_) {
      _snack('تعذّرت إضافة المحطة. تحقق من الاتصال وحاول مجدداً.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Station>>(
          stream: _stream,
          builder: (context, snap) {
            final data = snap.data;
            if (data != null) {
              _latest = data;
              _applyDistances(data);
              // تحديث الخريطة (إن كانت مفتوحة) بعد انتهاء البناء
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _stations.value = data;
              });
            }
            return IndexedStack(
              index: _tab,
              children: [
                StationsPage(
                  stations: data,
                  hasError: snap.hasError,
                  locating: _locating,
                  onLocate: _locate,
                  onOpen: _openStation,
                  governorateLabel: _gov.label,
                  governorateChosen: _gov.isChosen,
                  onPickGovernorate: _pickGovernorate,
                  onOpenMap: _openMap,
                ),
                FavoritesPage(stations: data, onOpen: _openStation),
                const SettingsPage(),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _addStation,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('إضافة محطة'),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdBanner(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.local_gas_station_outlined),
                selectedIcon: Icon(Icons.local_gas_station),
                label: 'المحطات',
              ),
              NavigationDestination(
                icon: Icon(Icons.star_border),
                selectedIcon: Icon(Icons.star),
                label: 'المفضلة',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'الإعدادات',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddStationDialog extends StatefulWidget {
  const _AddStationDialog({required this.initialGovernorate});

  final String initialGovernorate;

  @override
  State<_AddStationDialog> createState() => _AddStationDialogState();
}

class _AddStationDialogState extends State<_AddStationDialog> {
  final _name = TextEditingController();
  final _area = TextEditingController();
  late String _governorate = widget.initialGovernorate;

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _pickGovernorate() async {
    final v = await showGovernoratePicker(context,
        selected: _governorate, includeAll: false);
    if (v != null && mounted) setState(() => _governorate = v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة محطة جديدة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'قف داخل المحطة أو بجانبها تماماً؛ سيُسجَّل موقعك الحالي كموقع للمحطة.'),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المحطة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _area,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'الحي أو المنطقة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _pickGovernorate,
              icon: const Icon(Icons.location_city),
              label: Text('المحافظة: $_governorate'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (
              name: _name.text.trim(),
              area: _area.text.trim(),
              governorate: _governorate,
            ),
          ),
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}
