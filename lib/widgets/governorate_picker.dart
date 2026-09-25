import 'package:flutter/material.dart';

import '../data/governorates.dart';
import '../services/governorate_service.dart';

/// يعرض قائمة المحافظات ويعيد اسم المحافظة المختارة (أو [kAllIraq]).
Future<String?> showGovernoratePicker(
  BuildContext context, {
  required String? selected,
  bool includeAll = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            if (includeAll)
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('كل العراق'),
                subtitle: const Text('يحمّل كل المحطات وقد يستهلك بيانات أكثر'),
                trailing: selected == kAllIraq ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, kAllIraq),
              ),
            for (final g in kGovernorates)
              ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(g.name),
                trailing: selected == g.name ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, g.name),
              ),
          ],
        ),
      ),
    ),
  );
}
