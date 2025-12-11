import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.location.status;
    if (mounted) {
      setState(() {
        _locationGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestLocation() async {
    final status = await Permission.location.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      setState(() {
        _locationGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestOthers() async {
    try {
      await [Permission.notification, Permission.photos].request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  void _onGetStarted() async {
    if (!_locationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to continue.'),
        ),
      );
      return;
    }

    // Request other permissions (Notification/Photos)
    // We await this to ensure the dialogs are handled before navigation
    try {
      await _requestOthers().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Permission request timed out or failed: $e');
    }

    if (mounted) {
      print('Navigating to Home...');
      // Use pushNamedAndRemoveUntil to clear the back stack (Login, Register, etc.)
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'Permissions Required',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'To provide the best travel recommendations, we need access to your location.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Location (Required)'),
                trailing: _locationGranted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: _requestLocation,
                        child: const Text('Allow'),
                      ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _locationGranted ? _onGetStarted : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _locationGranted
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                  child: const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
