class Place {
  final String id;
  final Map<String, String>? nameLocalized; // locale -> name
  final String imageUrl;
  final double rating;
  final String location; // Coordinates or address
  final Map<String, String>? descriptionLocalized; // locale -> description
  final int commentCount;
  final double latitude;
  final double longitude;
  final String? price;
  final String? openingTime;
  final String? website;
  final List<PlaceComment> comments;

  Place({
    required this.id,
    this.nameLocalized,
    required this.imageUrl,
    required this.rating,
    required this.location,
    this.descriptionLocalized,
    required this.commentCount,
    required this.latitude,
    required this.longitude,
    this.price,
    this.openingTime,
    this.website,
    this.comments = const [],
  });

  String localizedName(String locale) {
    return nameLocalized?[locale] ?? nameLocalized?['en'] ?? '';
  }

  String localizedDescription(String locale) {
    return descriptionLocalized?[locale] ?? descriptionLocalized?['en'] ?? '';
  }
}

class PlaceComment {
  PlaceComment({
    required this.id,
    required this.author,
    required this.text,
    required this.rating,
    this.imagePath,
    required this.timestamp,
  });

  final String id;
  final String author;
  final String text;
  final int rating; // 1-5
  final String? imagePath; // local path or url
  final DateTime timestamp;
}
