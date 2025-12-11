import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/screens/auth/permissions_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  String? _selectedReligion;
  String _selectedCompanion = 'Solo';

  final List<String> _religions = [
    'None',
    'Buddhism',
    'Christianity',
    'Islam',
    'Hinduism',
  ];
  final List<String> _companions = ['Solo', 'Couple', 'Family', 'Friends'];

  void _onFinish() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.updateSurvey(
      religion: _selectedReligion,
      companionType: _selectedCompanion,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PermissionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about you')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Religion', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedReligion,
              items: _religions.map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (val) => setState(() => _selectedReligion = val),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Text(
              'Who do you travel with?',
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
                child: const Text('Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
