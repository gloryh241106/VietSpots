// ignore_for_file: deprecated_member_use

import 'dart:io' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/services/image_service.dart';
import 'package:vietspots/utils/avatar_image_provider.dart';
import 'package:vietspots/widgets/avatar_crop_dialog.dart';

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
  final _introductionController = TextEditingController();
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
      _introductionController.text = user.introduction ?? '';
      if (user.age != null) _age = user.age!;
      if (user.gender != null) _gender = user.gender!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _introductionController.dispose();
    super.dispose();
  }

  Future<void> _changeAvatar() async {
    // Let user choose Camera or Gallery, then request the appropriate permission.
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final loc = Provider.of<LocalizationProvider>(ctx, listen: false);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(loc.translate('gallery')),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(loc.translate('camera')),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                title: Text(
                  Provider.of<LocalizationProvider>(
                    ctx,
                    listen: false,
                  ).translate('cancel'),
                ),
                onTap: () => Navigator.pop(ctx, null),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    // Request appropriate permission
    if (choice == 'gallery') {
      Permission requestPerm = Permission.photos;
      if (io.Platform.isAndroid) requestPerm = Permission.storage;
      final status = await requestPerm.request();
      if (!status.isGranted) {
        final loc = Provider.of<LocalizationProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('photo_permission_required'))),
        );
        if (status.isPermanentlyDenied) openAppSettings();
        return;
      }
    } else if (choice == 'camera') {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        final loc = Provider.of<LocalizationProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('photo_permission_required'))),
        );
        if (status.isPermanentlyDenied) openAppSettings();
        return;
      }
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final croppedPath = await showAvatarCropDialog(
      context: context,
      imageBytes: bytes,
    );
    if (croppedPath == null || croppedPath.trim().isEmpty) return;

    if (mounted) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Upload the avatar image to Supabase
        final imageFile = io.File(croppedPath);
        final uploadResponse = await Provider.of<ImageService>(
          context,
          listen: false,
        ).uploadImages([imageFile]);

        // Get the uploaded image URL
        String? avatarUrl;
        if (uploadResponse.urls.isNotEmpty) {
          avatarUrl = uploadResponse.urls.first;
        }

        // Pop loading dialog
        if (mounted) Navigator.pop(context);

        // Update profile with the uploaded avatar URL
        if (mounted) {
          final success = await Provider.of<AuthProvider>(
            context,
            listen: false,
          ).updateProfile(avatarUrl: avatarUrl);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? Provider.of<LocalizationProvider>(
                          context,
                          listen: false,
                        ).translate('avatar_updated')
                      : 'Lỗi cập nhật avatar',
                ),
              ),
            );
            setState(() {});
          }
        }
      } catch (e) {
        // Pop loading dialog
        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tải lên: ${e.toString()}')),
          );
        }
      }
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
              child: SizedBox(
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant,
                      backgroundImage: avatarImageProvider(user?.avatarUrl),
                      child: user?.avatarUrl == null
                          ? Icon(
                              Icons.person,
                              size: 52,
                              color: Colors.grey[700],
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _changeAvatar,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Card(
                elevation: 1,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('personal_details'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: loc.translate('full_name'),
                          prefixIcon: const Icon(Icons.person),
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
                          prefixIcon: const Icon(Icons.email),
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
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return loc.translate('phone_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _introductionController,
                        decoration: InputDecoration(
                          labelText: loc.translate('introduction'),
                          prefixIcon: const Icon(Icons.edit),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      // Age on its own row for clearer layout
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${loc.translate('age')}: $_age'),
                          Slider(
                            value: _age.toDouble(),
                            min: 13,
                            max: 100,
                            divisions: 87,
                            label: '$_age',
                            onChanged: (v) => setState(() => _age = v.round()),
                          ),
                          const SizedBox(height: 12),
                          Text(loc.translate('gender')),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChoiceChip(
                                label: Text(loc.translate('male')),
                                selected: _gender == 'Male',
                                onSelected: (s) =>
                                    setState(() => _gender = 'Male'),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text(loc.translate('female')),
                                selected: _gender == 'Female',
                                onSelected: (s) =>
                                    setState(() => _gender = 'Female'),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: Text(loc.translate('other')),
                                selected: _gender == 'Other',
                                onSelected: (s) =>
                                    setState(() => _gender = 'Other'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(loc.translate('save_changes')),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;

                            final locLocal = loc; // capture before async gap
                            final auth = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );

                            final success = await auth.updateProfile(
                              name: _nameController.text.trim(),
                              email: _emailController.text.trim(),
                              phone: _phoneController.text.trim(),
                              introduction: _introductionController.text.trim(),
                              age: _age,
                              gender: _gender,
                            );

                            if (!mounted) return;

                            final messenger = ScaffoldMessenger.of(context);
                            if (success) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${locLocal.translate('save_changes')} ✓',
                                  ),
                                ),
                              );
                              if (mounted) Navigator.pop(context);
                            } else {
                              final err =
                                  auth.errorMessage ?? 'Lỗi lưu thay đổi';
                              messenger.showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
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
      body: ListView.separated(
        padding: const EdgeInsets.all(8),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: 4,
        itemBuilder: (context, index) {
          final items = [
            {
              'icon': Icons.tune,
              'title': loc.translate('preferences'),
              'subtitle': loc.translate('preferences_subtitle'),
              'route': PreferencesScreenSettings(),
            },
            {
              'icon': Icons.public,
              'title': loc.translate('culture'),
              'subtitle': loc.translate('culture_subtitle'),
              'route': CultureScreenSettings(),
            },
            {
              'icon': Icons.account_balance,
              'title': loc.translate('religion'),
              'subtitle': loc.translate('religion_subtitle'),
              'route': ReligionScreenSettings(),
            },
            {
              'icon': Icons.group,
              'title': loc.translate('companion_preference'),
              'subtitle': loc.translate('travel_companion'),
              'route': CompanionPreferenceScreenSettings(),
            },
          ];

          final item = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                item['icon'] as IconData,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(item['title'] as String),
            subtitle: Text(item['subtitle'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => item['route'] as Widget),
            ),
          );
        },
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
              (c) => ListTile(
                title: Text(labelForCulture(c)),
                selected: _selected == c,
                trailing: _selected == c
                    ? const Icon(Icons.radio_button_checked)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () => setState(() => _selected = c),
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
              (r) => ListTile(
                title: Text(labelForReligion(r)),
                selected: _selected == r,
                trailing: _selected == r
                    ? const Icon(Icons.radio_button_checked)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () => setState(() => _selected = r),
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
              (c) => ListTile(
                title: Text(labelForCompanion(c)),
                selected: _selected == c,
                trailing: _selected == c
                    ? const Icon(Icons.radio_button_checked)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () => setState(() => _selected = c),
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
              if (!context.mounted) return;
              setState(() => _location = granted);
              if (!granted) {
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
              if (!context.mounted) return;
              setState(() => _notification = granted);
              if (!granted) {
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
              if (!context.mounted) return;
              setState(() => _gallery = granted);
              if (!granted) {
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
            children: locProvider.supportedLanguages.entries
                .map((e) => _buildLangTile(context, e.value, e.key))
                .toList(),
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

// --- STT Language Selection ---

class SttLanguageScreen extends StatefulWidget {
  const SttLanguageScreen({super.key});

  @override
  State<SttLanguageScreen> createState() => _SttLanguageScreenState();
}

class _SttLanguageScreenState extends State<SttLanguageScreen> {
  final SpeechToText _speech = SpeechToText();
  List<LocaleName> _locales = [];
  String? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString('preferred_stt_language');
      _selected = current;
      final ok = await _speech.initialize();
      if (!ok) {
        setState(() {
          _locales = [];
          _loading = false;
        });
        return;
      }
      final locales = await _speech.locales();
      setState(() {
        _locales = locales;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _locales = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('language'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_locales.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(loc.translate('help_center_body')),
                  ),
                ..._locales.map((l) {
                  final id = l.localeId.replaceAll('_', '-');
                  final name = l.name;
                  final selected = _selected == id;
                  return ListTile(
                    title: Text('$name ($id)'),
                    trailing: selected ? const Icon(Icons.check) : null,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('preferred_stt_language', id);
                      setState(() => _selected = id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${loc.translate('stt_language')}: $name ($id)',
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          loc.translate('help_center_body'),
          style: const TextStyle(fontSize: 16, height: 1.5),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          loc.translate('legal_policy_body'),
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
