import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/screens/auth/permissions_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  String? _selectedReligion;
  String _selectedCompanion = 'Solo';
  String? _selectedHobby;

  final List<String> _religions = [
    'None',
    'Buddhism',
    'Christianity',
    'Islam',
    'Hinduism',
  ];
  final List<String> _companions = ['Solo', 'Couple', 'Family', 'Friends'];
  final List<String> _hobbies = [
    'Adventure',
    'Relax',
    'Culture',
    'Food',
    'Nature',
  ];

  void _onFinish() {
    if (_selectedReligion == null || _selectedReligion!.trim().isEmpty) {
      final loc = Provider.of<LocalizationProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('religion_required'))),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.updateSurvey(
      religion: _selectedReligion,
      hobby: _selectedHobby,
      companionType: _selectedCompanion,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PermissionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('tell_us_about_you'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.translate('religion'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedReligion,
                items: _religions.map((r) {
                  return DropdownMenuItem(value: r, child: Text(r));
                }).toList(),
                onChanged: (val) => setState(() => _selectedReligion = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              Text(
                loc.translate('your_hobby'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _hobbies.map((h) {
                  return ChoiceChip(
                    label: Text(h),
                    selected: _selectedHobby == h,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedHobby = h);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                loc.translate('travel_companion'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _companions.map((c) {
                  return ChoiceChip(
                    label: Text(c),
                    selected: _selectedCompanion == c,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCompanion = c);
                    },
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _onFinish,
                  child: Text(loc.translate('finish')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
