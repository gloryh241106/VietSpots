import 'package:flutter/material.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/utils/mock_data.dart';

class PlaceProvider extends ChangeNotifier {
  final List<Place> _places = [
    ...MockDataService.places,
    ...MockDataService.district12Places,
  ];
  final Set<String> _favoriteIds = {};

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
