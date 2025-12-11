import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';

// --- Section 1: Personal Information ---

class GeneralInfoScreen extends StatefulWidget {
  const GeneralInfoScreen({super.key});

  @override
  State<GeneralInfoScreen> createState() => _GeneralInfoScreenState();
}

class _GeneralInfoScreenState extends State<GeneralInfoScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      // _phoneController.text = user.phone ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('General Information')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage('https://picsum.photos/200'),
            ),
            TextButton(onPressed: () {}, child: const Text('Change Avatar')),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Save logic
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivateInfoScreen extends StatelessWidget {
  const PrivateInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Private Information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Special Needs'),
            subtitle: const Text('None'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Culture / Religion'),
            subtitle: const Text('None'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Companion Preference'),
            subtitle: const Text('Solo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// --- Section 2: Security & Permissions ---

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            const TextField(
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            const TextField(
              decoration: InputDecoration(labelText: 'Confirm New Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class PermissionsScreenSettings extends StatefulWidget {
  const PermissionsScreenSettings({super.key});

  @override
  State<PermissionsScreenSettings> createState() =>
      _PermissionsScreenSettingsState();
}

class _PermissionsScreenSettingsState extends State<PermissionsScreenSettings> {
  bool _location = true;
  bool _notification = true;
  bool _gallery = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Location Access'),
            value: _location,
            onChanged: (val) => setState(() => _location = val),
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            value: _notification,
            onChanged: (val) => setState(() => _notification = val),
          ),
          SwitchListTile(
            title: const Text('Photo Gallery'),
            value: _gallery,
            onChanged: (val) => setState(() => _gallery = val),
          ),
        ],
      ),
    );
  }
}

// --- Section 3: General (Language) ---

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<LocalizationProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(locProvider.translate('language'))),
      body: Stack(
        children: [
          ListView(
            children: [
              _buildLangTile(context, 'English', 'en'),
              _buildLangTile(context, 'Tiếng Việt', 'vi'),
              _buildLangTile(context, 'Русский', 'ru'),
              _buildLangTile(context, '中文', 'zh'),
            ],
          ),
          if (locProvider.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildLangTile(BuildContext context, String name, String code) {
    final locProvider = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    );
    final isSelected = locProvider.locale.languageCode == code;

    return ListTile(
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        if (!isSelected) {
          locProvider.setLanguage(code);
        }
      },
    );
  }
}

// --- Section 4: About ---

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
          'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
          'nisi ut aliquip ex ea commodo consequat.\n\n'
          'Duis aute irure dolor in reprehenderit in voluptate velit esse '
          'cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat '
          'cupidatat non proident, sunt in culpa qui officia deserunt mollit '
          'anim id est laborum.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}

class LegalPolicyScreen extends StatelessWidget {
  const LegalPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
          'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
          'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris '
          'nisi ut aliquip ex ea commodo consequat.\n\n'
          'Duis aute irure dolor in reprehenderit in voluptate velit esse '
          'cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat '
          'cupidatat non proident, sunt in culpa qui officia deserunt mollit '
          'anim id est laborum.',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
