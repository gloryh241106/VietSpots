import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'System Update',
        'subtitle': 'VietSpots 2.0 is now available with new AI features!',
        'time': '2 hours ago',
        'isUnread': true,
      },
      {
        'title': 'New Suggestion',
        'subtitle': 'Based on your recent trip to Da Lat, you might like...',
        'time': '1 day ago',
        'isUnread': false,
      },
      {
        'title': 'Welcome to VietSpots',
        'subtitle': 'Thanks for joining our community of travelers.',
        'time': '3 days ago',
        'isUnread': false,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final isUnread = notif['isUnread'] as bool;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isUnread
                  ? Colors.red.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                isUnread
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: isUnread ? Colors.red : Colors.grey,
              ),
            ),
            title: Text(
              notif['title'] as String,
              style: TextStyle(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notif['subtitle'] as String),
                const SizedBox(height: 4),
                Text(
                  notif['time'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            onTap: () {
              // Navigate to detail
            },
          );
        },
      ),
    );
  }
}
