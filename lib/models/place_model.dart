class Place {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final String location; // Coordinates or address
  final String description;
  final int commentCount;
  final double latitude;
  final double longitude;

  Place({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.location,
    required this.description,
    required this.commentCount,
    required this.latitude,
    required this.longitude,
  });
}
