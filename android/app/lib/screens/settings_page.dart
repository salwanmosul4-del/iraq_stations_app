import 'package:flutter/material.dart';

import '../config.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget section(String title, String body) => Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text('الإعدادات',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        section(
          'عن التطبيق',
          'تطبيق مجتمعي يعتمد على بلاغات المستخدمين لمعرفة حالة محطات الوقود '
              'في العراق: هل هي مفتوحة، وكم سيارة في الطابور، وما أنواع الوقود المتوفرة. '
              'اختر محافظتك من أعلى شاشة المحطات، أو اعرض كل العراق.',
        ),
        section(
          'كيف تعمل الحالة؟',
          '• الحالة المعروضة هي آخر بلاغ وصل للمحطة.\n'
              '• إذا مضت ${kStaleAfter.inHours} ساعات دون بلاغ تظهر "غير مؤكدة".\n'
              '• عدد السيارات يُعرض فقط إن كان البلاغ خلال آخر ${kQueueFreshFor.inMinutes} دقيقة.\n'
              '• وقت الانتظار تقدير تقريبي مبني على عدد السيارات، وليس رقماً دقيقاً.',
        ),
        section(
          'إرسال البلاغات',
          '• يجب أن تكون على بعد ${(kMaxReportDistanceMeters / 1000).toStringAsFixed(1)} كم أو أقل من المحطة.\n'
              '• بلاغ واحد كل ${kReportCooldown.inMinutes} دقائق لكل محطة.\n'
              '• لا حاجة لإنشاء حساب، ولا نطلب اسمك أو رقم هاتفك. يُستخدم موقعك للتحقق من قربك من المحطة ولعرض الأقرب إليك.',
        ),
        if (kShowOsmCredit)
          section(
            'مصدر بيانات المحطات',
            'مواقع بعض المحطات مأخوذة من © مساهمي OpenStreetMap (رخصة ODbL).',
          ),
      ],
    );
  }
}
