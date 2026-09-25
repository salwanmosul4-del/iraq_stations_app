import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../data/governorates.dart';
import '../models/station.dart';
import 'station_sheet.dart';

/// خريطة المحطات. تُرسم فقط المحطات الظاهرة في الشاشة (حتى [kMaxMapMarkers]) للحفاظ على السلاسة.
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.stations,
    required this.position,
    required this.governorate,
  });

  final ValueListenable<List<Station>> stations;
  final Position? position;

  /// null = كل العراق.
  final Governorate? governorate;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controller = MapController();
  Timer? _debounce;
  bool _ready = false;

  late final LatLng _initialCenter;
  late final double _initialZoom;

  @override
  void initState() {
    super.initState();
    final pos = widget.position;
    final gov = widget.governorate;
    if (gov != null) {
      if (pos != null &&
          Geolocator.distanceBetween(pos.latitude, pos.longitude, gov.lat, gov.lng) <
              60000) {
        _initialCenter = LatLng(pos.latitude, pos.longitude);
        _initialZoom = 13;
      } else {
        _initialCenter = LatLng(gov.lat, gov.lng);
        _initialZoom = 10;
      }
    } else if (pos != null) {
      _initialCenter = LatLng(pos.latitude, pos.longitude);
      _initialZoom = 12;
    } else {
      _initialCenter = const LatLng(33.3, 43.7); // وسط العراق تقريباً
      _initialZoom = 6;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _dist2(Station s, LatLng c) {
    final dy = s.lat - c.latitude;
    final dx = s.lng - c.longitude;
    return dx * dx + dy * dy;
  }

  ({List<Station> shown, bool capped}) _compute(List<Station> all) {
    if (!_ready) return (shown: const <Station>[], capped: false);
    final camera = _controller.camera;
    final bounds = camera.visibleBounds;
    final inView = all
        .where((s) =>
            (s.lat != 0 || s.lng != 0) && bounds.contains(LatLng(s.lat, s.lng)))
        .toList();
    if (inView.length <= kMaxMapMarkers) return (shown: inView, capped: false);
    final center = camera.center;
    inView.sort((a, b) => _dist2(a, center).compareTo(_dist2(b, center)));
    return (shown: inView.sublist(0, kMaxMapMarkers), capped: true);
  }

  void _openStation(Station s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StationSheet(station: s, position: widget.position),
    );
  }

  void _goToMe() {
    final pos = widget.position;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('موقعك غير معروف. فعّل GPS ثم ارجع لشاشة المحطات وحدّث موقعك.')),
      );
      return;
    }
    _controller.move(LatLng(pos.latitude, pos.longitude), 14);
  }

  Marker _stationMarker(Station s) {
    final c = s.effectiveStatus.color;
    return Marker(
      point: LatLng(s.lat, s.lng),
      width: 38,
      height: 38,
      child: GestureDetector(
        onTap: () => _openStation(s),
        child: Container(
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: const Icon(Icons.local_gas_station, size: 20, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final gov = widget.governorate;

    return Scaffold(
      appBar: AppBar(title: Text(gov == null ? 'خريطة المحطات — العراق' : 'خريطة المحطات — ${gov.name}')),
      body: ValueListenableBuilder<List<Station>>(
        valueListenable: widget.stations,
        builder: (context, stations, _) {
          final result = _compute(stations);
          return Stack(
            children: [
              // الخريطة نفسها تُرسم من اليسار لليمين حتى لا تتأثر باتجاه اللغة العربية
              Directionality(
                textDirection: TextDirection.ltr,
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    minZoom: 4,
                    maxZoom: 18,
                    onMapReady: () {
                      if (mounted) setState(() => _ready = true);
                    },
                    onPositionChanged: (camera, hasGesture) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 150), () {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: kTileUrl,
                      userAgentPackageName: 'com.mosul_gas',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final s in result.shown) _stationMarker(s),
                        if (pos != null)
                          Marker(
                            point: LatLng(pos.latitude, pos.longitude),
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),

              // مفتاح الألوان
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final st in StationStatus.values) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration:
                                BoxDecoration(color: st.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(st.label, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (result.capped)
                PositionedDirectional(
                  top: 56,
                  start: 10,
                  end: 10,
                  child: Card(
                    color: Colors.amber.shade100,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'تُعرض أقرب $kMaxMapMarkers محطة لمركز الخريطة. قرّب الخريطة لرؤية المزيد.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'موقعي',
        onPressed: _goToMe,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
