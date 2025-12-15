import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/utils/avatar_image_provider.dart';

// --- Section 1: Personal Information ---

class GeneralInfoScreen extends StatefulWidget {
  const GeneralInfoScreen({super.key});

  @override
  State<GeneralInfoScreen> createState() => _GeneralInfoScreenState();
}

class _GeneralInfoScreenState extends State<GeneralInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  int _age = 25;
  String _gender = 'Other';

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      if (user.age != null) _age = user.age!;
      if (user.gender != null) _gender = user.gender!;
    }
  }

  Future<void> _changeAvatar() async {
    // Request gallery permission before opening picker.
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      if (mounted) {
        final loc = Provider.of<LocalizationProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('photo_permission_required'))),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (mounted) {
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).updateProfile(avatarUrl: picked.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LocalizationProvider>(
              context,
              listen: false,
            ).translate('avatar_updated'),
          ),
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('general_information'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: avatarImageProvider(user?.avatarUrl),
                    child: user?.avatarUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  TextButton(
                    onPressed: _changeAvatar,
                    child: Text(loc.translate('change_avatar')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: loc.translate('full_name'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.translate('full_name_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: loc.translate('email'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.translate('email_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: loc.translate('phone_number'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.translate('phone_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${loc.translate('age')}: '),
                      Expanded(
                        child: Slider(
                          value: _age.toDouble(),
                          min: 13,
                          max: 100,
                          divisions: 87,
                          label: '$_age',
                          onChanged: (v) => setState(() => _age = v.round()),
                        ),
                      ),
                      SizedBox(width: 40, child: Text('$_age')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${loc.translate('gender')}: '),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: Text(loc.translate('male')),
                        selected: _gender == 'Male',
                        onSelected: (s) => setState(() => _gender = 'Male'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(loc.translate('female')),
                        selected: _gender == 'Female',
                        onSelected: (s) => setState(() => _gender = 'Female'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(loc.translate('other')),
                        selected: _gender == 'Other',
                        onSelected: (s) => setState(() => _gender = 'Other'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;

                        // Save back to provider.
                        Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).updateProfile(
                          name: _nameController.text.trim(),
                          email: _emailController.text.trim(),
                          phone: _phoneController.text.trim(),
                          age: _age,
                          gender: _gender,
                        );
                        Navigator.pop(context);
                      },
                      child: Text(loc.translate('save_changes')),
                    ),
                  ),
                ],
              ),
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
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('private_information'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(loc.translate('preferences')),
            subtitle: Text(loc.translate('preferences_subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PreferencesScreenSettings(),
              ),
            ),
          ),
          ListTile(
            title: Text(loc.translate('culture')),
            subtitle: Text(loc.translate('culture_subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CultureScreenSettings(),
              ),
            ),
          ),
          ListTile(
            title: Text(loc.translate('religion')),
            subtitle: Text(loc.translate('religion_subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReligionScreenSettings(),
              ),
            ),
          ),
          ListTile(
            title: Text(loc.translate('companion_preference')),
            subtitle: Text(loc.translate('travel_companion')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CompanionPreferenceScreenSettings(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreferencesScreenSettings extends StatefulWidget {
  const PreferencesScreenSettings({super.key});

  @override
  State<PreferencesScreenSettings> createState() =>
      _PreferencesScreenSettingsState();
}

class _PreferencesScreenSettingsState extends State<PreferencesScreenSettings> {
  final List<String> _options = const [
    'Adventure',
    'Less travelling',
    'Beautiful',
    'Mysterious',
    'Food',
    'Culture',
    'Nature',
    'Nightlife',
  ];

  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _selected = List<String>.from(user?.preferences ?? const <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    String labelForOption(String opt) {
      switch (opt) {
        case 'Adventure':
          return loc.translate('pref_adventure');
        case 'Less travelling':
          return loc.translate('pref_less_travelling');
        case 'Beautiful':
          return loc.translate('pref_beautiful');
        case 'Mysterious':
          return loc.translate('pref_mysterious');
        case 'Food':
          return loc.translate('pref_food');
        case 'Culture':
          return loc.translate('pref_culture');
        case 'Nature':
          return loc.translate('pref_nature');
        case 'Nightlife':
          return loc.translate('pref_nightlife');
        default:
          return opt;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('preferences'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((opt) {
              final isSelected = _selected.contains(opt);
              return FilterChip(
                label: Text(labelForOption(opt)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selected.add(opt);
                    } else {
                      _selected.remove(opt);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).updateSurvey(preferences: _selected);
                Navigator.pop(context);
              },
              child: Text(loc.translate('save')),
            ),
          ),
        ],
      ),
    );
  }
}

class CultureScreenSettings extends StatefulWidget {
  const CultureScreenSettings({super.key});

  @override
  State<CultureScreenSettings> createState() => _CultureScreenSettingsState();
}

class _CultureScreenSettingsState extends State<CultureScreenSettings> {
  final List<String> _cultures = const [
    'Vietnamese',
    'Chinese',
    'Japanese',
    'Korean',
    'Thai',
    'Indian',
    'Western / European',
    'American',
    'Middle Eastern',
    'African',
    'Other',
  ];

  String? _selected;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _selected = user?.culture;
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    String labelForCulture(String value) {
      switch (value) {
        case 'Vietnamese':
          return loc.translate('culture_vietnamese');
        case 'Chinese':
          return loc.translate('culture_chinese');
        case 'Japanese':
          return loc.translate('culture_japanese');
        case 'Korean':
          return loc.translate('culture_korean');
        case 'Thai':
          return loc.translate('culture_thai');
        case 'Indian':
          return loc.translate('culture_indian');
        case 'Western / European':
          return loc.translate('culture_western_european');
        case 'American':
          return loc.translate('culture_american');
        case 'Middle Eastern':
          return loc.translate('culture_middle_eastern');
        case 'African':
          return loc.translate('culture_african');
        case 'Other':
          return loc.translate('other');
        default:
          return value;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('culture'))),
      body: ListView(
        children: _cultures
            .map(
              (c) => RadioListTile<String>(
                value: c,
                groupValue: _selected,
                title: Text(labelForCulture(c)),
                onChanged: (val) => setState(() => _selected = val),
              ),
            )
            .toList(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).updateSurvey(culture: _selected);
                Navigator.pop(context);
              },
              child: Text(loc.translate('save')),
            ),
          ),
        ),
      ),
    );
  }
}

class ReligionScreenSettings extends StatefulWidget {
  const ReligionScreenSettings({super.key});

  @override
  State<ReligionScreenSettings> createState() => _ReligionScreenSettingsState();
}

class _ReligionScreenSettingsState extends State<ReligionScreenSettings> {
  final List<String> _religions = const [
    'None',
    'Buddhism',
    'Christianity',
    'Islam',
    'Hinduism',
    'Judaism',
    'Sikhism',
    'Other',
  ];

  String? _selected;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _selected = user?.religion;
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    String labelForReligion(String value) {
      switch (value) {
        case 'None':
          return loc.translate('religion_none');
        case 'Buddhism':
          return loc.translate('religion_buddhism');
        case 'Christianity':
          return loc.translate('religion_christianity');
        case 'Islam':
          return loc.translate('religion_islam');
        case 'Hinduism':
          return loc.translate('religion_hinduism');
        case 'Judaism':
          return loc.translate('religion_judaism');
        case 'Sikhism':
          return loc.translate('religion_sikhism');
        case 'Other':
          return loc.translate('other');
        default:
          return value;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('religion'))),
      body: ListView(
        children: _religions
            .map(
              (r) => RadioListTile<String>(
                value: r,
                groupValue: _selected,
                title: Text(labelForReligion(r)),
                onChanged: (val) => setState(() => _selected = val),
              ),
            )
            .toList(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).updateSurvey(religion: _selected);
                Navigator.pop(context);
              },
              child: Text(loc.translate('save')),
            ),
          ),
        ),
      ),
    );
  }
}

class CompanionPreferenceScreenSettings extends StatefulWidget {
  const CompanionPreferenceScreenSettings({super.key});

  @override
  State<CompanionPreferenceScreenSettings> createState() =>
      _CompanionPreferenceScreenSettingsState();
}

class _CompanionPreferenceScreenSettingsState
    extends State<CompanionPreferenceScreenSettings> {
  final List<String> _companions = const [
    'Solo',
    'Couple',
    'Family',
    'Friends',
  ];
  String _selected = 'Solo';

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _selected = user?.companionType ?? 'Solo';
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    String labelForCompanion(String value) {
      switch (value) {
        case 'Solo':
          return loc.translate('companion_solo');
        case 'Couple':
          return loc.translate('companion_couple');
        case 'Family':
          return loc.translate('companion_family');
        case 'Friends':
          return loc.translate('companion_friends');
        default:
          return value;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('companion_preference'))),
      body: ListView(
        children: _companions
            .map(
              (c) => RadioListTile<String>(
                value: c,
                groupValue: _selected,
                title: Text(labelForCompanion(c)),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _selected = val);
                },
              ),
            )
            .toList(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).updateSurvey(companionType: _selected);
                Navigator.pop(context);
              },
              child: Text(loc.translate('save')),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Section 2: Security & Permissions ---

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('change_password'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: currentController,
              decoration: InputDecoration(
                labelText: loc.translate('current_password'),
              ),
              obscureText: true,
            ),
            TextField(
              controller: newController,
              decoration: InputDecoration(
                labelText: loc.translate('new_password'),
              ),
              obscureText: true,
            ),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                labelText: loc.translate('confirm_new_password'),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final current = currentController.text;
                final next = newController.text;
                final confirm = confirmController.text;

                if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.translate('all_fields_required')),
                    ),
                  );
                  return;
                }

                if (!auth.verifyPassword(current)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        loc.translate('current_password_incorrect'),
                      ),
                    ),
                  );
                  return;
                }

                if (next != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        loc.translate('new_passwords_do_not_match'),
                      ),
                    ),
                  );
                  return;
                }

                auth.updatePassword(next);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.translate('update_password_success')),
                  ),
                );
                Navigator.pop(context);
              },
              child: Text(loc.translate('update_password')),
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

  Future<bool> _request(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('permissions'))),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(loc.translate('location_access')),
            value: _location,
            onChanged: (val) async {
              if (!val) {
                setState(() => _location = false);
                return;
              }
              final granted = await _request(Permission.locationWhenInUse);
              setState(() => _location = granted);
              if (!granted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.translate('location_permission_denied')),
                  ),
                );
              }
            },
          ),
          SwitchListTile(
            title: Text(loc.translate('notifications')),
            value: _notification,
            onChanged: (val) async {
              if (!val) {
                setState(() => _notification = false);
                return;
              }
              final granted = await _request(Permission.notification);
              setState(() => _notification = granted);
              if (!granted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      loc.translate('notification_permission_denied'),
                    ),
                  ),
                );
              }
            },
          ),
          SwitchListTile(
            title: Text(loc.translate('photo_gallery')),
            value: _gallery,
            onChanged: (val) async {
              if (!val) {
                setState(() => _gallery = false);
                return;
              }
              final granted = await _request(Permission.photos);
              setState(() => _gallery = granted);
              if (!granted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.translate('photo_permission_denied')),
                  ),
                );
              }
            },
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
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('help_center'))),
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
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('legal_policy'))),
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
