import 'package:flutter/material.dart';

import '../models/station.dart';
import '../utils/format.dart';

class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.isFavorite = false,
  });

  final Station station;
  final VoidCallback onTap;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = station.effectiveStatus;
    final subtitle = station.subtitle;
    final updated = station.updatedAt;
    final cars = station.queueCars;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // شريط ملوّن على بداية البطاقة بلون الحالة
              Container(width: 5, color: st.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isFavorite) ...[
                            Icon(Icons.star,
                                size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                          ],
                          StatusPill(status: st),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                      if (station.hasFreshQueue && cars != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car,
                                    size: 20, color: Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  cars == 0
                                      ? 'لا يوجد طابور'
                                      : 'حوالي $cars سيارة',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (cars > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.schedule,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(formatWaitRange(cars),
                                      style: theme.textTheme.bodyMedium),
                                ],
                              ),
                          ],
                        ),
                      ],
                      if (st == StationStatus.open &&
                          station.fuels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final f in FuelType.values)
                              if (station.fuels.contains(f))
                                FuelTag(label: f.label),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        updated == null
                            ? 'لم تُحدَّث بعد — كن أول من يبلّغ'
                            : station.isStale &&
                                    station.status != StationStatus.unknown
                                ? 'آخر بلاغ: ${station.status.label} · ${timeAgo(updated)}'
                                : 'آخر تحديث ${timeAgo(updated)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final StationStatus status;

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(status.label,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class FuelTag extends StatelessWidget {
  const FuelTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_gas_station, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: c, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
