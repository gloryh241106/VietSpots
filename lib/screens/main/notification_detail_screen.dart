import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/utils/typography.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('notification_details'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.heading3.copyWith(
                color: AppTextColors.primary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: AppTypography.caption.copyWith(
                color: AppTextColors.tertiary(context),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUnread
                    ? Theme.of(context).primaryColor.withOpacity(0.06)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTextColors.primary(context),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
