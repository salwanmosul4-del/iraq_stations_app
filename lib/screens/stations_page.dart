import 'package:flutter/material.dart';

import '../models/station.dart';
import '../services/favorites_service.dart';
import '../utils/arabic.dart';
import '../widgets/station_card.dart';

enum SortMode { nearest, shortestQueue, lastUpdate }

/// التبويب الرئيسي: بحث + فرز + فلاتر + قائمة المحطات.
class StationsPage extends StatefulWidget {
  const StationsPage({
    super.key,
    required this.stations,
    required this.hasError,
    required this.locating,
    required this.onLocate,
    required this.onOpen,
    required this.governorateLabel,
    required this.governorateChosen,
    required this.onPickGovernorate,
    required this.onOpenMap,
  });

  /// null = ما زالت قيد التحميل.
  final List<Station>? stations;
  final bool hasError;
  final bool locating;
  final Future<void> Function() onLocate;
  final void Function(Station) onOpen;

  /// اسم المحافظة المعروضة (أو "كل العراق").
  final String governorateLabel;
  final bool governorateChosen;
  final VoidCallback onPickGovernorate;
  final VoidCallback onOpenMap;

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  SortMode _sort = SortMode.nearest;
  FuelType? _fuel;
  bool _onlyOpen = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _byDistance(Station a, Station b) {
    final da = a.distanceMeters;
    final db = b.distanceMeters;
    if (da != null && db != null) return da.compareTo(db);
    return a.name.compareTo(b.name);
  }

  int _queueRank(Station s) {
    if (s.hasFreshQueue) return s.queueCars!;
    if (s.effectiveStatus == StationStatus.open) return 100000;
    return 200000;
  }

  List<Station> _apply(List<Station> all) {
    Iterable<Station> it = all;

    final q = normalizeArabic(_query);
    if (q.isNotEmpty) {
      it = it.where((s) =>
          normalizeArabic('${s.name} ${s.area} ${s.governorate}').contains(q));
    }
    if (_onlyOpen) {
      it = it.where((s) => s.effectiveStatus == StationStatus.open);
    }
    final fuel = _fuel;
    if (fuel != null) {
      it = it.where((s) => s.hasFuel(fuel));
    }

    final list = it.toList();
    switch (_sort) {
      case SortMode.nearest:
        list.sort(_byDistance);
      case SortMode.shortestQueue:
        list.sort((a, b) {
          final c = _queueRank(a).compareTo(_queueRank(b));
          return c != 0 ? c : _byDistance(a, b);
        });
      case SortMode.lastUpdate:
        list.sort((a, b) {
          final ua = a.updatedAt;
          final ub = b.updatedAt;
          if (ua == null && ub == null) return _byDistance(a, b);
          if (ua == null) return 1;
          if (ub == null) return -1;
          return ub.compareTo(ua);
        });
    }
    return list;
  }

  Widget _filters() {
    final chips = <Widget>[
      ChoiceChip(
        label: const Text('الكل'),
        selected: _fuel == null,
        onSelected: (_) => setState(() => _fuel = null),
      ),
      for (final f in FuelType.values)
        ChoiceChip(
          label: Text(f.label),
          selected: _fuel == f,
          onSelected: (_) => setState(() => _fuel = _fuel == f ? null : f),
        ),
      FilterChip(
        avatar: const Icon(Icons.check, size: 18),
        label: const Text('مفتوحة'),
        selected: _onlyOpen,
        showCheckmark: false,
        onSelected: (v) => setState(() => _onlyOpen = v),
      ),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _body(List<Station>? all, List<Station> list) {
    if (!widget.governorateChosen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_city, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text('اختر المحافظة لعرض محطاتها.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onPickGovernorate,
                child: const Text('اختر المحافظة'),
              ),
            ],
          ),
        ),
      );
    }
    if (all == null) {
      if (widget.hasError) {
        return const _Message(
          icon: Icons.cloud_off,
          text: 'تعذّر تحميل المحطات.\nتحقق من الاتصال بالإنترنت.',
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return _Message(
        icon: Icons.local_gas_station,
        text: all.isEmpty
            ? 'لا توجد محطات مسجّلة بعد.\nكن أول من يضيف محطة!'
            : 'لا توجد محطات مطابقة لبحثك.',
      );
    }
    return RefreshIndicator(
      onRefresh: widget.onLocate,
      child: ListenableBuilder(
        listenable: FavoritesService.instance,
        builder: (_, __) => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 90),
          itemCount: list.length,
          itemBuilder: (_, i) => StationCard(
            station: list[i],
            isFavorite: FavoritesService.instance.contains(list[i].id),
            onTap: () => widget.onOpen(list[i]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.stations;
    final list = all == null ? const <Station>[] : _apply(all);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'المحطات القريبة',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'تحديث موقعي',
                onPressed: widget.locating ? null : widget.onLocate,
                icon: widget.locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.location_city, size: 18),
                label: Text(widget.governorateLabel),
                onPressed: widget.onPickGovernorate,
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: widget.onOpenMap,
                icon: const Icon(Icons.map),
                label: const Text('الخريطة'),
              ),
              const Spacer(),
              if (all != null)
                Text('${list.length} محطة',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey.shade700)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن محطة أو حي',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<SortMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: SortMode.nearest, label: Text('الأقرب')),
                    ButtonSegment(
                        value: SortMode.shortestQueue, label: Text('أقصر طابور')),
                    ButtonSegment(
                        value: SortMode.lastUpdate, label: Text('آخر تحديث')),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (s) => setState(() => _sort = s.first),
                ),
              ),
            ],
          ),
        ),
        _filters(),
        const SizedBox(height: 6),
        Expanded(child: _body(all, list)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
