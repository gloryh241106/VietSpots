import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vietspots/screens/auth/edit_profile_screen.dart';
import 'package:vietspots/screens/auth/login_screen.dart';
import 'package:vietspots/screens/main/main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        Supabase.instance.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        // Check if we have data
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Get current session from the auth state
        final session = snapshot.data!.session;

        // If user is not logged in, show LoginScreen
        if (session == null) {
          return const LoginScreen();
        }

        // User is logged in, check if they've completed onboarding
        final user = session.user;
        final hasOnboarded = user.userMetadata?['has_onboarded'] ?? false;

        if (hasOnboarded) {
          // Onboarding complete, show MainScreen
          return const MainScreen();
        } else {
          // Need to complete onboarding
          return const EditProfileScreen();
        }
      },
    );
  }
}
