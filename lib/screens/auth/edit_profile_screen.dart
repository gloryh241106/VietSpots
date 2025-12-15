import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/screens/auth/survey_screen.dart';
import 'package:vietspots/utils/avatar_image_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _age = 25;
  String _gender = 'Other';

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

    // Store local path (or blob url on web) into `avatarUrl`.
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
    }
  }

  void _onNext() {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.updateProfile(
      name: _nameController.text,
      age: _age,
      gender: _gender,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SurveyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;
    if (_nameController.text.isEmpty && user != null) {
      _nameController.text = user.name;
    }
    if (user != null) {
      if (user.age != null) _age = user.age!;
      if (user.gender != null) _gender = user.gender!;
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('edit_profile'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: avatarImageProvider(user?.avatarUrl),
                  child: user?.avatarUrl == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _changeAvatar,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(loc.translate('change_avatar')),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: loc.translate('full_name'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return loc.translate('full_name_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _onNext,
                    child: Text(loc.translate('next')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
