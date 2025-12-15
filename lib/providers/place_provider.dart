import 'package:flutter/material.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/utils/mock_data.dart';

class PlaceProvider extends ChangeNotifier {
  final List<Place> _places = [
    ...MockDataService.places,
    ...MockDataService.district12Places,
  ];
  final Set<String> _favoriteIds = {};

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
  }
}
