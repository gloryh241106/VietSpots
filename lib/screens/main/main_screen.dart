import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/screens/main/chat_screen.dart';
import 'package:vietspots/screens/main/favorites_screen.dart';
import 'package:vietspots/screens/main/home_screen.dart';
import 'package:vietspots/screens/main/notification_screen.dart';
import 'package:vietspots/screens/main/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const NotificationScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.home,
                  label: loc.translate('home'),
                  tabIndex: 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.favorite,
                  label: loc.translate('favorites'),
                  tabIndex: 1,
                ),
              ),
              const SizedBox(width: 64), // space for FAB
              Expanded(
                child: _buildNavItem(
                  icon: Icons.notifications,
                  label: loc.translate('notification'),
                  tabIndex: 2,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.settings,
                  label: loc.translate('settings'),
                  tabIndex: 3,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.smart_toy),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int? tabIndex,
    VoidCallback? onTap,
  }) {
    final isSelected = tabIndex != null && _currentIndex == tabIndex;
    return InkWell(
      onTap: onTap ?? (tabIndex == null ? null : () => _onItemTapped(tabIndex)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 26,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
