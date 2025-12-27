import 'dart:convert';
import 'api_service.dart';
import '../models/place_model.dart';

/// Place API DTO (Data Transfer Object)
class PlaceDTO {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? website;
  final String? category;
  final double? rating;
  final int? ratingCount;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? openingHours;
  final Map<String, dynamic>? about;
  final double? distanceKm;
  final List<String>? images;
  final List<dynamic>? comments;
  final int? commentCount;
  // Chat-specific fields from ChatbotOrchestrator
  final Map<String, dynamic>? weather;
  final double? score;

  PlaceDTO({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.website,
    this.category,
    this.rating,
    this.ratingCount,
    required this.latitude,
    required this.longitude,
    this.openingHours,
    this.about,
    this.distanceKm,
    this.images,
    this.comments,
    this.commentCount,
    this.weather,
    this.score,
  });

  factory PlaceDTO.fromJson(Map<String, dynamic> json) {
    // Backend returns flat latitude/longitude fields
    final lat = json['latitude'] ?? json['coordinates']?['lat'] ?? 0.0;
    final lon = json['longitude'] ?? json['coordinates']?['lon'] ?? 0.0;

    return PlaceDTO(
      id: json['id'] ?? json['place_id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      website: json['website'],
      category: json['category'],
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'],
      latitude: (lat as num).toDouble(),
      longitude: (lon as num).toDouble(),
      openingHours: json['opening_hours'] is Map
          ? json['opening_hours']
          : (json['opening_hours'] is String
                ? {'raw': json['opening_hours']}
                : null),
      about: json['about'] is Map
          ? json['about']
          : (json['about'] is String ? {'text': json['about']} : null),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      images: (json['images'] as List<dynamic>?)
          ?.map((e) {
            // Backend returns array of strings, not objects
            if (e is String) return e;
            if (e is Map) return e['url'] as String? ?? '';
            return e.toString();
          })
          .where((url) => url.isNotEmpty)
          .toList(),
      comments: json['comments'] is List
          ? json['comments'] as List<dynamic>
          : (json['comments'] is String
                ? (jsonDecode(json['comments']) as List<dynamic>?)
                : null),
      commentCount:
          (json['comment_count'] as int?) ?? (json['comments_count'] as int?),
      // Chat-specific fields from ChatbotOrchestrator
      weather: json['weather'] is Map ? json['weather'] : null,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  /// Format about object into human-readable text
  String _formatAbout(dynamic aboutData) {
    // Handle case where aboutData might be a string representation of a Python dict
    if (aboutData is! Map) {
      if (aboutData is String) {
        // Check if it's a Python dict representation like {'key': 'value', ...}
        final strData = aboutData.toString().trim();
        if (strData.startsWith('{') && strData.endsWith('}')) {
          // Try to convert Python dict to JSON and parse
          try {
            // Convert Python dict to JSON format
            String jsonStr = strData
                .replaceAll(
                  "'",
                  '"',
                ) // Replace single quotes with double quotes
                .replaceAll('True', 'true')
                .replaceAll('False', 'false')
                .replaceAll('None', 'null');
            final parsed = jsonDecode(jsonStr);
            if (parsed is Map) {
              return _formatAboutMap(parsed.cast<String, dynamic>());
            }
          } catch (e) {
            // If parsing fails, return a cleaned up version
            return 'Không có thông tin chi tiết.';
          }
        }
        // If it's a simple text description
        if (strData.length < 500 &&
            !strData.contains("'parking':") &&
            !strData.contains('"parking":')) {
          return strData;
        }
        return 'Không có thông tin chi tiết.';
      }
      return 'Không có thông tin chi tiết.';
    }

    // aboutData is a Map at this point
    if (aboutData is Map<String, dynamic>) {
      return _formatAboutMap(aboutData);
    }
    // ignore: unnecessary_cast
    return _formatAboutMap(Map<String, dynamic>.from(aboutData));
  }

  /// Format parsed about map into human-readable text
  String _formatAboutMap(Map<String, dynamic> data) {
    final List<String> sections = [];

    // Extract description text if present
    if (data['description'] != null &&
        data['description'].toString().isNotEmpty) {
      sections.add(data['description'].toString());
    }
    if (data['text'] != null && data['text'].toString().isNotEmpty) {
      sections.add(data['text'].toString());
    }

    // Category labels with emojis
    final categoryLabels = {
      'amenities': '🏠 Tiện nghi',
      'service_options': '🍽️ Dịch vụ',
      'parking': '🅿️ Đỗ xe',
      'planning': '📋 Đặt chỗ',
      'payments': '💳 Thanh toán',
      'beverages': '🍺 Đồ uống',
      'highlights': '⭐ Điểm nổi bật',
      'accessibility': '♿ Tiếp cận',
      'dining_options': '🍴 Phục vụ',
    };

    for (final entry in categoryLabels.entries) {
      final key = entry.key;
      final label = entry.value;

      if (data[key] is Map) {
        final Map<String, dynamic> items = (data[key] as Map)
            .cast<String, dynamic>();
        final enabledItems = items.entries
            .where((e) => e.value == true)
            .map((e) => '• ${e.key}')
            .toList();
        if (enabledItems.isNotEmpty) {
          sections.add('$label\n${enabledItems.join('\n')}');
        }
      }
    }

    return sections.isNotEmpty
        ? sections.join('\n\n')
        : 'Không có thông tin chi tiết.';
  }

  /// Parse opening hours from string or map
  Map<String, dynamic>? _parseOpeningHours(dynamic hours) {
    if (hours == null) return null;
    if (hours is Map) return hours.cast<String, dynamic>();
    if (hours is String) {
      final strData = hours.trim();
      // Check if it contains 'raw:' prefix
      if (strData.startsWith('raw:')) {
        final rawPart = strData.substring(4).trim();
        return _parseOpeningHours(rawPart);
      }
      // Check if it's a Python dict like {'Thứ Hai': '10:00-22:00', ...}
      if (strData.startsWith('{') && strData.endsWith('}')) {
        try {
          String jsonStr = strData
              .replaceAll("'", '"')
              .replaceAll('True', 'true')
              .replaceAll('False', 'false')
              .replaceAll('None', 'null');
          final parsed = jsonDecode(jsonStr);
          if (parsed is Map) {
            return parsed.cast<String, dynamic>();
          }
        } catch (e) {
          // Return as simple text
          return {'raw': strData};
        }
      }
      return {'raw': strData};
    }
    return null;
  }

  /// Format opening hours into readable text with line breaks
  String? _formatOpeningHours(dynamic hoursData) {
    final hours = _parseOpeningHours(hoursData);
    if (hours == null || hours.isEmpty) return null;

    // Check for raw string format
    if (hours.containsKey('raw')) {
      final raw = hours['raw'].toString();
      // Try to parse the raw value if it looks like a dict
      if (raw.startsWith('{')) {
        final parsed = _parseOpeningHours(raw);
        if (parsed != null && !parsed.containsKey('raw')) {
          return _formatOpeningHoursMap(parsed);
        }
      }
      // It's just a simple string
      return raw;
    }

    return _formatOpeningHoursMap(hours);
  }

  /// Format parsed opening hours map
  String? _formatOpeningHoursMap(Map<String, dynamic> hours) {
    if (hours.isEmpty) return null;

    // Order days from Monday to Sunday
    final dayOrder = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    final orderedEntries = <String>[];
    for (final day in dayOrder) {
      if (hours.containsKey(day)) {
        orderedEntries.add('$day: ${hours[day]}');
      }
    }

    // Add any remaining days not in the standard order
    for (final entry in hours.entries) {
      if (!dayOrder.contains(entry.key)) {
        orderedEntries.add('${entry.key}: ${entry.value}');
      }
    }

    return orderedEntries.isNotEmpty ? orderedEntries.join('\n') : null;
  }

  /// Convert to app's Place model
  Place toPlace() {
    // Convert raw comment DTOs into PlaceComment instances
    final parsedComments = <PlaceComment>[];
    if (comments != null) {
      for (final c in comments!) {
        try {
          if (c is Map) {
            final cid = (c['id'] ?? c['comment_id'] ?? '').toString();
            final author = (c['author'] ?? c['user'] ?? 'Unknown').toString();
            final text = (c['text'] ?? c['comment'] ?? '').toString();
            final ratingVal = (c['rating'] is num)
                ? (c['rating'] as num).toInt()
                : 0;
            final imagePath = (c['image'] ?? c['image_url'])?.toString();
            DateTime timestamp;
            if (c['timestamp'] is String) {
              timestamp = DateTime.tryParse(c['timestamp']) ?? DateTime.now();
            } else if (c['timestamp'] is int) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(c['timestamp']);
            } else {
              timestamp = DateTime.now();
            }

            parsedComments.add(
              PlaceComment(
                id: cid.isNotEmpty
                    ? cid
                    : '${id}_c${parsedComments.length}_${DateTime.now().millisecondsSinceEpoch}',
                author: author,
                text: text,
                rating: ratingVal,
                imagePath: imagePath,
                timestamp: timestamp,
              ),
            );
          }
        } catch (_) {
          // ignore malformed comment entries
        }
      }
    }

    // Prefer actual parsed comments when available; otherwise fall back to
    // provided `commentCount` from the backend. This avoids showing an
    // incorrect count when the DTO includes actual comment objects.
    final effectiveCommentCount = parsedComments.isNotEmpty
        ? parsedComments.length
        : (commentCount ?? 0);

    return Place(
      id: id,
      nameLocalized: {'vi': name, 'en': name},
      imageUrl: images?.isNotEmpty == true ? images!.first : '',
      rating: rating ?? 0.0,
      location: address ?? '',
      descriptionLocalized: about != null
          ? {'vi': _formatAbout(about!), 'en': _formatAbout(about!)}
          : null,
      commentCount: effectiveCommentCount,
      latitude: latitude,
      longitude: longitude,
      price: null,
      openingTime: openingHours != null
          ? _formatOpeningHours(openingHours!)
          : null,
      website: website,
      comments: parsedComments,
    );
  }
}

/// Service for Places API
class PlaceService {
  final ApiService _api;

  PlaceService(this._api);

  /// GET /places - Get list of places
  Future<List<PlaceDTO>> getPlaces({
    int skip = 0,
    int limit = 20,
    double? lat,
    double? lon,
    int? maxDistance,
    String? location,
    String? categories,
    double? minRating,
    String? search,
    String sortBy = 'rating',
  }) async {
    // If a search query is provided, call the dedicated search RPC endpoint
    // `/places/search` which runs fuzzy search on the DB.
    if (search != null && search.trim().isNotEmpty) {
      final response = await _api.get(
        '/places/search',
        queryParams: {
          'keyword': search,
          if (lat != null) 'lat': lat,
          if (lon != null) 'lon': lon,
          'limit': limit,
        },
      );

      return (response as List).map((e) => PlaceDTO.fromJson(e)).toList();
    }

    final response = await _api.get(
      '/places',
      queryParams: {
        'skip': skip,
        'limit': limit,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (maxDistance != null) 'max_distance': maxDistance,
        if (location != null) 'location': location,
        if (categories != null) 'categories': categories,
        if (minRating != null) 'min_rating': minRating,
        'sort_by': sortBy,
      },
    );

    return (response as List).map((e) => PlaceDTO.fromJson(e)).toList();
  }

  /// GET /places/nearby - Get nearby places
  Future<List<PlaceDTO>> getNearbyPlaces({
    required double lat,
    required double lon,
    int radius = 5,
    String? categories,
    double? minRating,
    int limit = 20,
  }) async {
    final response = await _api.get(
      '/places/nearby',
      queryParams: {
        'lat': lat,
        'lon': lon,
        'radius': radius,
        if (categories != null) 'categories': categories,
        if (minRating != null) 'min_rating': minRating,
        'limit': limit,
      },
    );

    return (response as List).map((e) => PlaceDTO.fromJson(e)).toList();
  }

  /// GET /places/categories - Get all categories
  Future<List<String>> getCategories() async {
    final response = await _api.get('/places/categories');
    return (response as List).cast<String>();
  }

  /// GET /places/{place_id} - Get place details
  Future<PlaceDTO> getPlace(String placeId) async {
    final response = await _api.get('/places/$placeId');
    return PlaceDTO.fromJson(response);
  }

  /// POST /places - Create new place
  Future<Map<String, dynamic>> createPlace({
    required String name,
    String? address,
    String? phone,
    String? website,
    String? category,
    double? rating,
    int? ratingCount,
    Map<String, dynamic>? openingHours,
    Map<String, dynamic>? about,
    Map<String, double>? coordinates,
  }) async {
    return await _api.post(
      '/places',
      body: {
        'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (category != null) 'category': category,
        if (rating != null) 'rating': rating,
        if (ratingCount != null) 'rating_count': ratingCount,
        if (openingHours != null) 'opening_hours': openingHours,
        if (about != null) 'about': about,
        if (coordinates != null) 'coordinates': coordinates,
      },
    );
  }

  /// PUT /places/{place_id} - Update place
  Future<Map<String, dynamic>> updatePlace(
    String placeId, {
    String? name,
    String? address,
    String? phone,
    String? website,
    String? category,
    double? rating,
    int? ratingCount,
    Map<String, dynamic>? openingHours,
    Map<String, dynamic>? about,
    Map<String, double>? coordinates,
  }) async {
    return await _api.put(
      '/places/$placeId',
      body: {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (category != null) 'category': category,
        if (rating != null) 'rating': rating,
        if (ratingCount != null) 'rating_count': ratingCount,
        if (openingHours != null) 'opening_hours': openingHours,
        if (about != null) 'about': about,
        if (coordinates != null) 'coordinates': coordinates,
      },
    );
  }

  /// DELETE /places/{place_id} - Delete place
  Future<dynamic> deletePlace(String placeId) async {
    return await _api.delete('/places/$placeId');
  }
}
