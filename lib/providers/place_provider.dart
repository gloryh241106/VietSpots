import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/services/place_service.dart';
import 'package:vietspots/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PlaceProvider extends ChangeNotifier {
  final PlaceService _placeService;
  List<Place> _places = [];
  List<Place> _nearbyPlaces = [];
  List<Place> _recommendedPlaces = [];
  final List<Place> _visitedPlaces =
      []; // Places user has actually visited/commented
  final Set<String> _favoriteIds = {};
  bool _isLoading = false;
  String? _error;
  Position? _userPosition;

  PlaceProvider(this._placeService) {
    _initializeData();
    _loadFavorites();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Place> get nearbyPlaces => _nearbyPlaces;
  List<Place> get recommendedPlaces => _recommendedPlaces;
  List<Place> get visitedPlaces => _visitedPlaces;

  Future<void> _initializeData() async {
    await _getUserLocation();
    await loadPlaces();
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        _error = 'Vui lòng bật dịch vụ vị trí';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          _error = 'Quyền vị trí bị từ chối';
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        _error =
            'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng vào Cài đặt để cấp quyền.';
        return;
      }

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // NOTE: Removed emulator latitude override. Do not override real user coordinates.

      debugPrint(
        'Got location: ${_userPosition?.latitude}, ${_userPosition?.longitude}',
      );
    } catch (e) {
      debugPrint('Failed to get location: $e');
      _error = 'Không thể lấy vị trí: $e';
    }
  }

  // Manage comments in-memory
  void addComment(String placeId, PlaceComment comment) {
    final idx = _places.indexWhere((p) => p.id == placeId);
    if (idx == -1) return;
    final place = _places[idx];
    final updated = Place(
      id: place.id,
      nameLocalized: place.nameLocalized,
      imageUrl: place.imageUrl,
      rating:
          ((place.rating * place.commentCount) + comment.rating) /
          (place.commentCount + 1),
      location: place.location,
      descriptionLocalized: place.descriptionLocalized,
      commentCount: place.commentCount + 1,
      latitude: place.latitude,
      longitude: place.longitude,
      price: place.price,
      openingTime: place.openingTime,
      website: place.website,
      comments: [...place.comments, comment],
    );
    _places[idx] = updated;
    notifyListeners();
  }

  void setComments(String placeId, List<PlaceComment> comments) {
    final idx = _places.indexWhere((p) => p.id == placeId);
    if (idx == -1) return;
    final place = _places[idx];
    final updated = Place(
      id: place.id,
      nameLocalized: place.nameLocalized,
      imageUrl: place.imageUrl,
      rating: place.rating,
      location: place.location,
      descriptionLocalized: place.descriptionLocalized,
      // Keep the original total reviews from backend; don't override with page size
      commentCount: place.commentCount,
      latitude: place.latitude,
      longitude: place.longitude,
      price: place.price,
      openingTime: place.openingTime,
      website: place.website,
      comments: comments,
    );
    _places[idx] = updated;
    notifyListeners();
  }

  List<Place> get places => _places;

  List<Place> get favoritePlaces {
    return _places.where((place) => _favoriteIds.contains(place.id)).toList();
  }

  bool isFavorite(String id) {
    return _favoriteIds.contains(id);
  }

  void toggleFavorite(String id) {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    notifyListeners();
    _saveFavorites();
  }

  static const String _prefsFavoritesKey = 'favorite_place_ids';

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_prefsFavoritesKey) ?? [];
      _favoriteIds
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsFavoritesKey, _favoriteIds.toList());
    } catch (e) {
      debugPrint('Failed to save favorites: $e');
    }
  }

  /// Load all places from backend
  Future<void> loadPlaces({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Request places near user location for recommended (100km radius)
      final dtos = await _placeService
          .getPlaces(
            limit: limit,
            lat: _userPosition?.latitude,
            lon: _userPosition?.longitude,
            maxDistance: _userPosition != null
                ? 100
                : null, // 100km radius from user
            sortBy: 'rating',
            minRating: 0.1,
          )
          .timeout(const Duration(seconds: 30));

      // Convert all DTOs to Place objects
      final allPlaces = dtos.map((dto) => dto.toPlace()).toList();
      debugPrint('Loaded ${allPlaces.length} places near user location');

      _places = allPlaces;

      // Recommended: rank by combined score (rating + proximity) for better relevance
      _recommendedPlaces = _rankPlaces(_places).take(10).toList();
      debugPrint('Recommended places: ${_recommendedPlaces.length}');

      // Load nearby places if we have location
      if (_userPosition != null) {
        await loadNearbyPlaces();
      } else {
        // No location - keep nearby empty
        _nearbyPlaces = [];
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading places: $e');
      if (e.toString().contains('TimeoutException')) {
        debugPrint(
          '⚠️ Backend connection timeout - ensure backend is running at ${ApiConfig.baseUrl}',
        );
      }
      // Keep empty lists on error
      _places = [];
      _recommendedPlaces = [];
      _nearbyPlaces = [];
    } finally {
      _isLoading = false;
      debugPrint(
        '✅ Loading complete. Total places: ${_places.length}, Recommended: ${_recommendedPlaces.length}',
      );
      notifyListeners();
    }
  }

  /// Load nearby places based on user location
  Future<void> loadNearbyPlaces({int radius = 50}) async {
    if (_userPosition == null) return;

    try {
      // Request nearby places with actual ratings (minRating filters nulls)
      final dtos = await _placeService.getNearbyPlaces(
        lat: _userPosition!.latitude,
        lon: _userPosition!.longitude,
        radius: radius,
        minRating: 0.1,
        limit: 20,
      );

      // Convert to Place objects
      final places = dtos.map((dto) => dto.toPlace()).toList();
      debugPrint('Loaded ${places.length} nearby places');

      // Backend already sorts by distance, just add rating as secondary sort
      places.sort((a, b) {
        // Nearby API returns sorted by distance already, so rating is secondary
        final ratingCompare = b.rating.compareTo(a.rating);
        return ratingCompare;
      });

      _nearbyPlaces = places;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading nearby places: $e');
      _nearbyPlaces = [];
      notifyListeners();
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    _error = null;
    notifyListeners();

    // Get user location first
    await _getUserLocation();

    // Load places
    await loadPlaces();

    // If location was obtained, make sure nearby places are loaded
    if (_userPosition != null) {
      await loadNearbyPlaces();
    }
  }

  /// Sort a list of places by rating (highest first), with commentCount as secondary sort
  /// Returns a new sorted list (does not modify original)
  static List<Place> sortPlacesByRating(List<Place> places) {
    final placesWithRating = places.where((p) => p.rating > 0).toList();

    if (placesWithRating.isNotEmpty) {
      // Has places with rating > 0 - sort by rating descending
      placesWithRating.sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        // Secondary: comment count descending
        return b.commentCount.compareTo(a.commentCount);
      });
      return placesWithRating;
    } else {
      // All ratings are 0 - sort by comment count instead
      final sorted = List<Place>.from(places);
      sorted.sort((a, b) => b.commentCount.compareTo(a.commentCount));
      return sorted;
    }
  }

  // Minimal ranking combining rating and distance to improve relevance.
  List<Place> _rankPlaces(List<Place> places) {
    if (places.isEmpty) return [];

    double userLat = _userPosition?.latitude ?? double.nan;
    double userLon = _userPosition?.longitude ?? double.nan;

    // compute score = 0.6*rating_norm + 0.4*(1 - dist_norm)
    final maxDistanceKm = 100.0; // cap distance normalization

    double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
      // Haversine formula
      const R = 6371.0; // km
      double toRad(double deg) => deg * (3.141592653589793 / 180.0);
      final dLat = toRad(lat2 - lat1);
      final dLon = toRad(lon2 - lon1);
      final a =
          (sin(dLat / 2) * sin(dLat / 2)) +
          cos(toRad(lat1)) * cos(toRad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return R * c;
    }

    final scored = places.map((p) {
      final ratingNorm = (p.rating / 5.0).clamp(0.0, 1.0);
      double distScore = 0.0;
      if (userLat.isNaN == false && userLon.isNaN == false) {
        final d = _distanceKm(userLat, userLon, p.latitude, p.longitude);
        final dNorm = (d / maxDistanceKm).clamp(0.0, 1.0);
        distScore = 1.0 - dNorm; // nearer -> higher
      }
      final score = 0.6 * ratingNorm + 0.4 * distScore;
      return {'place': p, 'score': score};
    }).toList();

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scored.map((e) => e['place'] as Place).toList();
  }
}
