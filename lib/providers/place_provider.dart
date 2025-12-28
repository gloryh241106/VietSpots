import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/services/place_service.dart';
import 'package:vietspots/services/api_service.dart';
import 'package:vietspots/services/comment_service.dart';
import 'package:geolocator/geolocator.dart';
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      // EMULATOR FIX: Override with Vietnam location for testing
      // Remove this in production!
      if (_userPosition!.latitude < 0 || _userPosition!.latitude > 40) {
        debugPrint(
          '⚠️ Detected emulator location, using Ho Chi Minh City coordinates for testing',
        );
        _userPosition = Position(
          latitude: 10.8231,
          longitude: 106.6297,
          timestamp: DateTime.now(),
          accuracy: 100,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

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
    // Update the place entry in all lists where it appears so UI stays consistent.
    void updateInList(List<Place> list) {
      final i = list.indexWhere((p) => p.id == placeId);
      if (i == -1) return;
      final place = list[i];
      List<PlaceComment> merged = [...place.comments, comment];
      // Deduplicate by id while preserving order (keep first occurrence)
      final seen = <String>{};
      merged = merged.where((c) => seen.add(c.id)).toList();

      final updated = Place(
        id: place.id,
        nameLocalized: place.nameLocalized,
        imageUrl: place.imageUrl,
        // Recalculate average rating using existing commentCount
        rating:
            ((place.rating * place.commentCount) + comment.rating) /
            (place.commentCount + 1),
        location: place.location,
        descriptionLocalized: place.descriptionLocalized,
        commentCount: place.commentCount + 1,
        // Preserve ratingCount if backend provided it so we don't hide it
        ratingCount: place.ratingCount,
        latitude: place.latitude,
        longitude: place.longitude,
        price: place.price,
        openingTime: place.openingTime,
        website: place.website,
        comments: merged,
      );
      list[i] = updated;
    }

    updateInList(_places);
    updateInList(_nearbyPlaces);
    updateInList(_recommendedPlaces);
    updateInList(_visitedPlaces);
    notifyListeners();
  }

  void setComments(
    String placeId,
    List<PlaceComment> comments, {
    bool replaceCount = false,
  }) {
    // Update comments in any lists that may contain this place
    void updateInList(List<Place> list) {
      final i = list.indexWhere((p) => p.id == placeId);
      if (i == -1) return;
      final p = list[i];
      final mergedComments = () {
        // For preview loads (replaceCount == false) prefer keeping the
        // existing comment list if it's larger than the preview returned
        // by the server. This avoids overwriting a locally-added comment
        // or a previously-fetched full list with a short preview (limit=3).
        if (!replaceCount) {
          if (p.comments.length >= comments.length) return p.comments;
        }
        // Ensure unique comments (server may return overlapping pages)
        final seen = <String>{};
        return comments.where((c) => seen.add(c.id)).toList();
      }();

      final updated = Place(
        id: p.id,
        nameLocalized: p.nameLocalized,
        imageUrl: p.imageUrl,
        rating: p.rating,
        location: p.location,
        descriptionLocalized: p.descriptionLocalized,
        // Only replace the recorded comment count when explicitly requested
        // (e.g. when loading full comments in detail screen). For preview
        // loads (limit=3) we preserve the backend-provided commentCount so
        // the UI shows the total reviews like the web client.
        commentCount: replaceCount ? comments.length : p.commentCount,
        ratingCount: p.ratingCount,
        latitude: p.latitude,
        longitude: p.longitude,
        price: p.price,
        openingTime: p.openingTime,
        website: p.website,
        comments: mergedComments,
      );
      list[i] = updated;
    }

    updateInList(_places);
    updateInList(_nearbyPlaces);
    updateInList(_recommendedPlaces);
    updateInList(_visitedPlaces);

    notifyListeners();
  }

  /// Insert or update a Place in all internal lists so UI can find AI-generated places
  void upsertPlace(Place place) {
    void updateList(List<Place> list) {
      final i = list.indexWhere((p) => p.id == place.id);
      if (i == -1) {
        list.insert(0, place);
      } else {
        list[i] = place;
      }
    }

    updateList(_places);
    updateList(_nearbyPlaces);
    updateList(_recommendedPlaces);
    // visited places should not be auto-inserted

    notifyListeners();
  }

  List<Place> get places => _places;

  List<Place> get favoritePlaces {
    return _places.where((place) => _favoriteIds.contains(place.id)).toList();
  }

  bool isFavorite(String id) {
    return _favoriteIds.contains(id);
  }

  Future<void> toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      notifyListeners();
      await _saveFavorites();
      return;
    }

    // Add to favorites set first so UI updates immediately
    _favoriteIds.add(id);
    notifyListeners();
    await _saveFavorites();

    // If the place isn't already loaded in memory, try to fetch details
    final exists = _places.any((p) => p.id == id);
    if (!exists) {
      try {
        final dto = await _placeService.getPlace(id);
        final place = dto.toPlace();
        // Insert at top so it shows in favorites and lists
        _places.insert(0, place);
        // Keep recommended/nearby lists consistent - don't modify them here
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to fetch place details for favorite id $id: $e');
      }
    }
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

      // Convert all DTOs to Place objects and preserve existing fields
      final allPlaces = dtos
          .map((dto) => dto.toPlace())
          .map((newP) => _mergePreserveFields(newP))
          .toList();
      debugPrint('Loaded ${allPlaces.length} places near user location');

      // Debug: print rating/comment counts for each loaded place
      // Removed per-place debug logging

      _places = allPlaces;

      // Sort by rating (highest first), then by comment count as secondary
      final sortedByRating = List<Place>.from(_places)
        ..sort((a, b) {
          // Primary: rating descending
          final ratingCompare = b.rating.compareTo(a.rating);
          if (ratingCompare != 0) return ratingCompare;
          // Secondary: comment count descending
          return b.commentCount.compareTo(a.commentCount);
        });

      _recommendedPlaces = sortedByRating.take(10).toList();
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
      // Use the same endpoint parameters as the web client: call /api/places
      // with `max_distance` (maxDistance) so the backend returns the same
      // `rating_count` metadata. This mirrors the web client's behavior and
      // avoids discrepancies between `/places` and `/places/nearby`.
      final dtos = await _placeService.getPlaces(
        limit: 20,
        lat: _userPosition!.latitude,
        lon: _userPosition!.longitude,
        maxDistance: radius,
        minRating: 0.1,
        sortBy: 'distance',
      );

      // Convert to Place objects and preserve cached fields where possible
      final places = dtos
          .map((dto) => dto.toPlace())
          .map((p) => _mergePreserveFields(p))
          .toList();
      debugPrint('Loaded ${places.length} nearby places');

      // Backend already sorts by distance, just add rating as secondary sort
      places.sort((a, b) {
        // Nearby API returns sorted by distance already, so rating is secondary
        final ratingCompare = b.rating.compareTo(a.rating);
        return ratingCompare;
      });

      _nearbyPlaces = places;

      // Load comments for nearby places asynchronously (don't block UI)
      _loadCommentsForPlaces(places);

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading nearby places: $e');
      _nearbyPlaces = [];
      notifyListeners();
    }
  }

  /// Load comments for multiple places
  Future<void> _loadCommentsForPlaces(List<Place> places) async {
    // This runs in the background without blocking UI
    for (final place in places) {
      try {
        final api = ApiService();
        final service = CommentService(api);
        final dtos = await service.getPlaceComments(place.id, limit: 10);
        final comments = dtos.map((d) => d.toPlaceComment()).toList();
        // Preview load: do NOT replace the backend's total comment count.
        setComments(place.id, comments, replaceCount: false);
      } catch (e) {
        debugPrint('Failed to load comments for place ${place.id}: $e');
        // Continue loading other places
      }
    }
    notifyListeners();
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

  /// Merge incoming place with any cached copy to preserve fields that
  /// may be absent from list endpoints (for example `ratingCount` or
  /// recently-loaded `comments`). Prefers authoritative fields from
  /// the incoming place but falls back to cached values when needed.
  Place _mergePreserveFields(Place incoming) {
    try {
      Place? existing;
      // Search all lists for an existing entry
      for (final list in [
        _places,
        _nearbyPlaces,
        _recommendedPlaces,
        _visitedPlaces,
      ]) {
        final i = list.indexWhere((p) => p.id == incoming.id);
        if (i != -1) {
          existing = list[i];
          break;
        }
      }

      if (existing == null) return incoming;

      final ratingCount =
          (incoming.ratingCount != null && incoming.ratingCount! > 0)
          ? incoming.ratingCount
          : existing.ratingCount;

      final commentCount = (incoming.commentCount > 0)
          ? incoming.commentCount
          : existing.commentCount;

      final comments = (incoming.comments.isNotEmpty)
          ? incoming.comments
          : existing.comments;

      return Place(
        id: incoming.id,
        nameLocalized: incoming.nameLocalized ?? existing.nameLocalized,
        imageUrl: incoming.imageUrl.isNotEmpty
            ? incoming.imageUrl
            : existing.imageUrl,
        rating: incoming.rating != 0 ? incoming.rating : existing.rating,
        location: incoming.location.isNotEmpty
            ? incoming.location
            : existing.location,
        descriptionLocalized:
            incoming.descriptionLocalized ?? existing.descriptionLocalized,
        commentCount: commentCount,
        ratingCount: ratingCount ?? 0,
        latitude: incoming.latitude != 0
            ? incoming.latitude
            : existing.latitude,
        longitude: incoming.longitude != 0
            ? incoming.longitude
            : existing.longitude,
        price: incoming.price ?? existing.price,
        openingTime: incoming.openingTime ?? existing.openingTime,
        website: incoming.website ?? existing.website,
        comments: comments,
      );
    } catch (e) {
      debugPrint('Failed to merge cached place fields for ${incoming.id}: $e');
      return incoming;
    }
  }
}
