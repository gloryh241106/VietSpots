import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/screens/main/notification_detail_screen.dart';
import 'package:vietspots/utils/typography.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final notifications = [
      {
        'title': loc.translate('notif_system_update_title'),
        'subtitle': loc.translate('notif_system_update_subtitle'),
        'time': loc.translate('notif_system_update_time'),
        'isUnread': true,
      },
      {
        'title': loc.translate('notif_new_suggestion_title'),
        'subtitle': loc.translate('notif_new_suggestion_subtitle'),
        'time': loc.translate('notif_new_suggestion_time'),
        'isUnread': false,
      },
      {
        'title': loc.translate('notif_welcome_title'),
        'subtitle': loc.translate('notif_welcome_subtitle'),
        'time': loc.translate('notif_welcome_time'),
        'isUnread': false,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: Text(
          loc.translate('notifications'),
          style:
              Theme.of(context).appBarTheme.titleTextStyle ??
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final notif = notifications[index];
            final isUnread = notif['isUnread'] as bool;

            return Container(
              color: isUnread
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.06)
                  : Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: isUnread
                          ? Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      child: Icon(
                        isUnread
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: isUnread
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  notif['title'] as String,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    color: AppTextColors.primary(context),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      notif['subtitle'] as String,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTextColors.secondary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif['time'] as String,
                      style: AppTypography.caption.copyWith(
                        color: AppTextColors.tertiary(context),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationDetailScreen(
                        title: notif['title'] as String,
                        subtitle: notif['subtitle'] as String,
                        time: notif['time'] as String,
                        isUnread: isUnread,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
