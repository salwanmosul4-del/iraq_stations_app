import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/station.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/station_service.dart';
import '../utils/format.dart';
import '../widgets/station_card.dart';

/// ورقة سفلية: تفاصيل المحطة + إرسال بلاغ عن حالتها + الاتجاهات.
class StationSheet extends StatefulWidget {
  const StationSheet({super.key, required this.station, required this.position});

  final Station station;
  final Position? position;

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  StationStatus? _picked; // open | closed
  int? _cars; // null حتى يحرّك المستخدم الشريط
  final Set<FuelType> _fuels = {};
  bool _sending = false;
  String? _error;

  bool get _isOpen => _picked == StationStatus.open;
  bool get _canSend => _picked == StationStatus.closed || (_isOpen && _cars != null);

  Future<void> _submit() async {
    final picked = _picked;
    if (picked == null || !_canSend || _sending) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final s = widget.station;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final pos = await LocationService.current() ?? widget.position;
      if (pos == null) {
        _fail('فعّل الموقع (GPS) وامنح التطبيق صلاحية الموقع لتتمكن من إرسال بلاغ.');
        return;
      }

      final distance =
          Geolocator.distanceBetween(pos.latitude, pos.longitude, s.lat, s.lng);
      if (distance > kMaxReportDistanceMeters) {
        _fail(
            'يجب أن تكون قرب المحطة (خلال ${formatDistance(kMaxReportDistanceMeters)}) لإرسال بلاغ. أنت على بعد ${formatDistance(distance)}.');
        return;
      }

      final left = await StationService.instance.cooldownLeft(s.id);
      if (left != null) {
        _fail(
            'أرسلت بلاغاً عن هذه المحطة قبل قليل. يمكنك إرسال بلاغ جديد بعد ${left.inMinutes + 1} دقيقة.');
        return;
      }

      await StationService.instance.report(
        station: s,
        status: picked,
        queueCars: _cars,
        fuels: _fuels,
      );

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('تم إرسال البلاغ. شكراً لمساهمتك!')),
      );
    } catch (_) {
      _fail('تعذّر إرسال البلاغ. تحقق من الاتصال بالإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _navigate() async {
    final s = widget.station;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _fail('تعذّر فتح تطبيق الخرائط.');
    } catch (_) {
      _fail('تعذّر فتح تطبيق الخرائط.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final st = s.effectiveStatus;
    final theme = Theme.of(context);
    final updated = s.updatedAt;
    final dist = s.distanceMeters;
    final cars = s.queueCars;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- العنوان + المفضلة ----
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: FavoritesService.instance,
                    builder: (_, __) {
                      final fav = FavoritesService.instance.contains(s.id);
                      return IconButton(
                        tooltip: fav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                        onPressed: () => FavoritesService.instance.toggle(s.id),
                        icon: Icon(
                          fav ? Icons.star : Icons.star_border,
                          color: fav ? Colors.amber.shade700 : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  StatusPill(status: st),
                  const SizedBox(width: 10),
                  if (s.subtitle.isNotEmpty)
                    Expanded(
                      child: Text(s.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (dist != null)
                Text('على بعد ${formatDistance(dist)}',
                    style: theme.textTheme.bodyMedium),
              if (s.hasFreshQueue && cars != null)
                Text(
                  cars == 0
                      ? 'لا يوجد طابور حالياً'
                      : 'الطابور: حوالي $cars سيارة · الانتظار ${formatWaitRange(cars)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              if (st == StationStatus.open && s.fuels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in FuelType.values)
                        if (s.fuels.contains(f)) FuelTag(label: f.label),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                updated == null
                    ? 'لا توجد بلاغات عن هذه المحطة بعد.'
                    : 'آخر تحديث ${timeAgo(updated)} · ${s.reportsCount} بلاغ',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade700),
              ),
              const Divider(height: 28),

              // ---- البلاغ ----
              Text('أبلغ عن الحالة الآن',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final c in const [StationStatus.open, StationStatus.closed])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(c.icon, size: 18, color: c.color),
                          label: Center(child: Text(c.label)),
                          selected: _picked == c,
                          onSelected: _sending
                              ? null
                              : (_) => setState(() => _picked = c),
                        ),
                      ),
                    ),
                ],
              ),
              if (_isOpen) ...[
                const SizedBox(height: 16),
                Text('عدد السيارات في الطابور',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Slider(
                  value: (_cars ?? 0).toDouble(),
                  min: 0,
                  max: 200,
                  divisions: 40,
                  label: '${_cars ?? 0}',
                  onChanged: _sending
                      ? null
                      : (v) => setState(() => _cars = v.round()),
                ),
                Text(
                  _cars == null
                      ? 'حرّك الشريط لتحديد عدد السيارات تقريباً.'
                      : _cars == 0
                          ? 'لا يوجد طابور'
                          : 'حوالي $_cars سيارة · تقدير الانتظار ${formatWaitRange(_cars!)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Text('ما المتوفر حالياً؟',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in FuelType.values)
                      FilterChip(
                        label: Text(f.label),
                        selected: _fuels.contains(f),
                        onSelected: _sending
                            ? null
                            : (v) => setState(() {
                                  if (v) {
                                    _fuels.add(f);
                                  } else {
                                    _fuels.remove(f);
                                  }
                                }),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_canSend && !_sending) ? _submit : null,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: const Text('إرسال البلاغ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _navigate,
                      icon: const Icon(Icons.directions),
                      label: const Text('الاتجاهات'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
