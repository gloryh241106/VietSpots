import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/chat_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/providers/theme_provider.dart';
import 'package:vietspots/screens/main/main_screen.dart';
import 'package:vietspots/screens/splash_screen.dart';
import 'package:vietspots/screens/auth/login_screen.dart';
import 'package:vietspots/utils/theme.dart';

void main() {
  runApp(const VietSpotsApp());
}

class VietSpotsApp extends StatelessWidget {
  const VietSpotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PlaceProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'VietSpots',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/home': (context) => const MainScreen(),
              '/login': (context) => const LoginScreen(),
            },
          );
        },
      ),
    );
  }
}
