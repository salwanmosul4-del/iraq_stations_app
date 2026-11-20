import 'package:flutter/material.dart';

import '../models/station.dart';
import '../services/favorites_service.dart';
import '../widgets/station_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key, required this.stations, required this.onOpen});

  /// null = ما زالت قيد التحميل.
  final List<Station>? stations;
  final void Function(Station) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('المفضلة',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: FavoritesService.instance,
            builder: (context, _) {
              final all = stations;
              if (all == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final favs = all
                  .where((s) => FavoritesService.instance.contains(s.id))
                  .toList()
                ..sort((a, b) {
                  final da = a.distanceMeters;
                  final db = b.distanceMeters;
                  if (da != null && db != null) return da.compareTo(db);
                  return a.name.compareTo(b.name);
                });

              if (favs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_border, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد محطات مفضلة بعد.\nافتح أي محطة واضغط على النجمة لإضافتها.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                itemCount: favs.length,
                itemBuilder: (_, i) => StationCard(
                  station: favs[i],
                  isFavorite: true,
                  onTap: () => onOpen(favs[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
