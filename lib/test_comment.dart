import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/api_service.dart';
import 'services/place_service.dart';
import 'services/comment_service.dart';
import 'services/auth_service.dart';

void main() async {
  debugPrint('🚀 Testing create comment...');

  final api = ApiService();
  final placeService = PlaceService(api);
  final commentService = CommentService(api);
  final authService = AuthService();

  try {
    // Try to load .env and sign in a test user if credentials present
    try {
      await dotenv.load();
    } catch (_) {}

    final testAccessToken = dotenv.env['TEST_ACCESS_TOKEN'];
    final testUserId = dotenv.env['TEST_USER_ID'];
    final testEmail = dotenv.env['TEST_USER_EMAIL'];
    final testPassword = dotenv.env['TEST_USER_PASSWORD'];

    // Prefer a supplied access token (fast, safe for CI)
    if (testAccessToken != null && testUserId != null) {
      debugPrint('Using TEST_ACCESS_TOKEN from .env');
      api.setAccessToken(testAccessToken);
      api.setUserId(testUserId);
    } else if (testEmail != null && testPassword != null) {
      debugPrint('Signing in test user from .env...');
      final authResp = await authService.signInWithEmail(
        email: testEmail,
        password: testPassword,
      );

      if (authResp.success && authResp.session != null) {
        api.setAccessToken(authResp.session!.accessToken);
        api.setUserId(authResp.session!.user.id);
        debugPrint('Test user signed in. UserId=${authResp.session!.user.id}');
      } else {
        debugPrint('Test sign-in failed: ${authResp.message}');
      }
    } else {
      debugPrint('No TEST_USER_EMAIL / TEST_USER_PASSWORD in .env — attempting ephemeral signup...');
      // Create an ephemeral test user (example.com safe domain) to run integration test
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ephemeralEmail = 'vietspot-integ-$ts@example.com';
      final ephemeralPassword = 'TestPass!${ts.toString().substring(ts.toString().length - 6)}';

      final signUpResp = await authService.signUpWithEmail(
        email: ephemeralEmail,
        password: ephemeralPassword,
      );

      if (signUpResp.success && signUpResp.session != null) {
        api.setAccessToken(signUpResp.session!.accessToken);
        api.setUserId(signUpResp.session!.user.id);
        debugPrint('Ephemeral test user signed up. UserId=${signUpResp.session!.user.id}');
      } else {
        debugPrint('Ephemeral signup failed: ${signUpResp.message}');
        debugPrint('Proceeding unauthenticated (will likely 401).');
      }
    }
    final places = await placeService.getPlaces(limit: 1);
    if (places.isEmpty) {
      debugPrint('No places found to attach comment to.');
      return;
    }

    final place = places.first;
    debugPrint('Using place: ${place.name} (${place.id})');

    final resp = await commentService.createComment(
      placeId: place.id,
      authorName: 'Integration Test',
      rating: 5,
      text: 'Test comment from automated integration test',
      imageUrls: [],
    );

    debugPrint('Create comment response: success=${resp.success} message=${resp.message}');
  } catch (e) {
    debugPrint('Error during comment test: $e');
  } finally {
    api.dispose();
    authService.dispose();
  }
}
