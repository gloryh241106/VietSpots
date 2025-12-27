import 'package:flutter_dotenv/flutter_dotenv.dart';

// Return a Tile URL template for TrackAsia tiles.
// Priority:
// 1. `TRACKASIA_TILE_TEMPLATE` in .env (must include {z}/{x}/{y})
// 2. Build from `TRACKASIA_API_KEY` using tiles.track-asia.com host
// 3. Fallback: tiles.track-asia.com template without key
String trackAsiaTileUrl() {
  final template = dotenv.env['TRACKASIA_TILE_TEMPLATE'];
  if (template != null && template.isNotEmpty) return template;

  final key = dotenv.env['TRACKASIA_API_KEY'] ?? '';
  if (key.isNotEmpty) {
    // Use TrackAsia raster tiles endpoint (correct path for PNG raster tiles)
    return 'https://tiles.track-asia.com/raster-tiles/v2/{z}/{x}/{y}.png?key=$key';
  }

  // Fallback to raster-tiles host without key
  return 'https://tiles.track-asia.com/raster-tiles/v2/{z}/{x}/{y}.png';
}
