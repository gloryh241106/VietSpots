import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/providers/theme_provider.dart';
import 'package:vietspots/screens/settings/settings_tree.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final locProvider = Provider.of<LocalizationProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(locProvider.translate('settings')),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(user.avatarUrl ?? ''),
                    onBackgroundImageError: (_, __) {},
                    child: user.avatarUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Personal Information'),
          _buildSettingsCard(context, [
            _buildSettingsTile(
              context,
              icon: Icons.person_outline,
              title: 'General Information',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GeneralInfoScreen(),
                ),
              ),
            ),
            _buildDivider(),
            _buildSettingsTile(
              context,
              icon: Icons.lock_outline,
              title: 'Private Information',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivateInfoScreen(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Security & Permissions'),
          _buildSettingsCard(context, [
            _buildSettingsTile(
              context,
              icon: Icons.password,
              title: 'Change Password',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              ),
            ),
            _buildDivider(),
            _buildSettingsTile(
              context,
              icon: Icons.security_outlined,
              title: 'Permissions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionsScreenSettings(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'General'),
          _buildSettingsCard(context, [
            _buildSettingsTile(
              context,
              icon: Icons.dark_mode_outlined,
              title: locProvider.translate('dark_mode'),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (val) => themeProvider.toggleTheme(val),
              ),
            ),
            _buildDivider(),
            _buildSettingsTile(
              context,
              icon: Icons.language,
              title: locProvider.translate('language'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguageScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'About'),
          _buildSettingsCard(context, [
            _buildSettingsTile(
              context,
              icon: Icons.help_outline,
              title: 'Help Center',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpCenterScreen(),
                ),
              ),
            ),
            _buildDivider(),
            _buildSettingsTile(
              context,
              icon: Icons.policy_outlined,
              title: 'Legal Policy',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalPolicyScreen(),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsCard(context, [
            _buildSettingsTile(
              context,
              icon: Icons.logout,
              title: locProvider.translate('logout'),
              titleColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => _showLogoutDialog(context),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final locProvider = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locProvider.translate('logout')),
        content: Text(locProvider.translate('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(locProvider.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              _performLogout(context);
            },
            child: Text(
              locProvider.translate('yes'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _performLogout(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    await Future.delayed(const Duration(seconds: 2)); // Simulate network

    if (context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? Theme.of(context).primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: titleColor),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 60);
  }
}
