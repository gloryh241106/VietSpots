import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/chat_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/providers/theme_provider.dart';
import 'package:vietspots/screens/main/main_screen.dart';
import 'package:vietspots/screens/splash_screen.dart';
import 'package:vietspots/screens/auth/login_screen.dart';
import 'package:vietspots/services/api_service.dart';
import 'package:vietspots/services/image_service.dart';
import 'package:vietspots/services/place_service.dart';
import 'package:vietspots/services/chat_service.dart';
import 'package:vietspots/services/outbound_queue.dart';
import 'package:vietspots/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vietspots/services/auth_service.dart';
import 'package:vietspots/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env (don't crash if missing)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Log and continue; .env may not be present on the device build.
    // The app should still run and can rely on defaults or remote config.
    debugPrint('dotenv.load() failed: $e');
  }

  // Initialize API services
  final apiService = ApiService();
  final imageService = ImageService(apiService);
  final placeService = PlaceService(apiService);
  final chatService = ChatService(apiService);

  // Initialize Supabase (uses SupabaseConfig in auth_service.dart)
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Storage service for uploading images to Supabase
  final storageService = StorageService();

  final outboundQueue = OutboundQueue();

  runApp(
    VietSpotsApp(
      apiService: apiService,
      imageService: imageService,
      placeService: placeService,
      chatService: chatService,
      storageService: storageService,
      outboundQueue: outboundQueue,
    ),
  );
}

class VietSpotsApp extends StatelessWidget {
  final ApiService apiService;
  final ImageService imageService;
  final PlaceService placeService;
  final ChatService chatService;
  final StorageService storageService;
  final OutboundQueue? outboundQueue;
  const VietSpotsApp({
    super.key,
    required this.apiService,
    required this.imageService,
    required this.placeService,
    required this.chatService,
    required this.storageService,
    this.outboundQueue,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide services
        Provider<ApiService>.value(value: apiService),
        Provider<ImageService>.value(value: imageService),
        Provider<PlaceService>.value(value: placeService),
        Provider<ChatService>.value(value: chatService),
        Provider<StorageService>.value(value: storageService),
        // Providers with dependencies
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            chatService,
            placeService,
            outboundQueue ?? OutboundQueue(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PlaceProvider(placeService)),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<LocalizationProvider>(
            builder: (context, locProvider, child) {
              return MaterialApp(
                title: locProvider.translate('app_name'),
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                locale: locProvider.locale,
                home: const SplashScreen(),
                routes: {
                  '/home': (context) => const MainScreen(),
                  '/login': (context) => const LoginScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}
