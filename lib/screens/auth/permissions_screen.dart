import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';

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
      final loc = Provider.of<LocalizationProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('location_required_to_continue'))),
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
      debugPrint('Navigating to Home...');
      // Use pushNamedAndRemoveUntil to clear the back stack (Login, Register, etc.)
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
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
                loc.translate('permissions_required_title'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                loc.translate('permissions_required_desc'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: Text(loc.translate('location_required')),
                trailing: _locationGranted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: _requestLocation,
                        child: Text(loc.translate('allow')),
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
                  child: Text(loc.translate('get_started')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
