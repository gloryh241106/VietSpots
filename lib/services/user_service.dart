import 'api_service.dart';
import 'comment_service.dart';

/// User commented place DTO
class UserCommentedPlaceDTO {
  final String id;
  final String? name;
  final String? address;
  final String? category;
  final double? rating;
  final Map<String, dynamic>? coordinates;

  UserCommentedPlaceDTO({
    required this.id,
    this.name,
    this.address,
    this.category,
    this.rating,
    this.coordinates,
  });

  factory UserCommentedPlaceDTO.fromJson(Map<String, dynamic> json) {
    return UserCommentedPlaceDTO(
      id: json['id'] ?? '',
      name: json['name'],
      address: json['address'],
      category: json['category'],
      rating: (json['rating'] as num?)?.toDouble(),
      coordinates: json['coordinates'],
    );
  }
}

/// User commented places response
class UserCommentedPlacesResponse {
  final bool success;
  final int count;
  final List<UserCommentedPlaceDTO> places;

  UserCommentedPlacesResponse({
    required this.success,
    required this.count,
    required this.places,
  });

  factory UserCommentedPlacesResponse.fromJson(Map<String, dynamic> json) {
    return UserCommentedPlacesResponse(
      success: json['success'] ?? false,
      count: json['count'] ?? 0,
      places:
          (json['places'] as List<dynamic>?)
              ?.map((e) => UserCommentedPlaceDTO.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Service for Users API
class UserService {
  final ApiService _api;

  UserService(this._api);

  /// GET /users/{user_id}/comments - Get user's comments
  Future<List<CommentDTO>> getUserComments(
    String userId, {
    int limit = 20000,
    int offset = 0,
  }) async {
    final response = await _api.get(
      '/users/$userId/comments',
      queryParams: {'limit': limit, 'offset': offset},
    );

    return (response as List).map((e) => CommentDTO.fromJson(e)).toList();
  }

  /// GET /api/users/{user_id}/commented-places - Get places user has commented on
  Future<UserCommentedPlacesResponse> getUserCommentedPlaces(
    String userId, {
    int limit = 20000,
    int offset = 0,
  }) async {
    final response = await _api.get(
      '/users/$userId/commented-places',
      queryParams: {'limit': limit, 'offset': offset},
    );

    return UserCommentedPlacesResponse.fromJson(response);
  }
}
