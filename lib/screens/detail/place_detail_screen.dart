import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/detail/directions_map_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceDetailScreen extends StatelessWidget {
  final Place place;

  const PlaceDetailScreen({super.key, required this.place});

  void _openDirections(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectionsMapScreen(place: place),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    final url = place.website;
    if (url == null || url.trim().isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('could_not_open_website'))),
      );
    }
  }

  void _showAddComment(BuildContext context) async {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    final TextEditingController ctrl = TextEditingController();
    int rating = 5;
    XFile? image;
    Uint8List? imageBytes;
    bool showError = false;
    final picker = ImagePicker();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('add_review'),
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (int i = 1; i <= 5; i++)
                            IconButton(
                              onPressed: () => setState(() => rating = i),
                              icon: Icon(
                                i <= rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                              ),
                            ),
                        ],
                      ),
                      TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          hintText: loc.translate('review_hint'),
                          errorText: showError
                              ? loc.translate('review_required')
                              : null,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 70,
                              );
                              if (picked == null) return;
                              final bytes = await picked.readAsBytes();
                              setState(() {
                                image = picked;
                                imageBytes = bytes;
                              });
                            },
                            child: Text(loc.translate('attach_image')),
                          ),
                          const SizedBox(width: 12),
                          if (imageBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                imageBytes!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(loc.translate('cancel')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (ctrl.text.trim().isEmpty) {
                                  setState(() => showError = true);
                                  return;
                                }

                                final comment = PlaceComment(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  author: 'You',
                                  rating: rating,
                                  text: ctrl.text.trim(),
                                  imagePath: image?.path,
                                  timestamp: DateTime.now(),
                                );
                                Provider.of<PlaceProvider>(
                                  context,
                                  listen: false,
                                ).addComment(place.id, comment);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc.translate('review_added'),
                                    ),
                                  ),
                                );
                              },
                              child: Text(loc.translate('submit')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHighlightChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final locale = loc.locale.languageCode;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                place.localizedName(locale),
                style: const TextStyle(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black54,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: place.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[300]),
                  ),
                  Container(color: Colors.black26),
                ],
              ),
            ),
            actions: [
              Consumer<PlaceProvider>(
                builder: (context, placeProvider, _) {
                  final isFav = placeProvider.isFavorite(place.id);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      placeProvider.toggleFavorite(place.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFav
                                ? 'Removed from Favorites'
                                : 'Added to Favorites',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Consumer<PlaceProvider>(
                        builder: (context, provider, _) {
                          final p = provider.places.firstWhere(
                            (e) => e.id == place.id,
                            orElse: () => place,
                          );
                          final reviewCount = p.comments.isNotEmpty
                              ? p.comments.length
                              : p.commentCount;
                          return Text(
                            '($reviewCount reviews)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Highlights
                  Text(
                    'Highlights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildHighlightChip(Icons.wifi, 'Free WiFi'),
                      _buildHighlightChip(Icons.local_parking, 'Parking'),
                      _buildHighlightChip(Icons.restaurant, 'Restaurant'),
                      _buildHighlightChip(Icons.photo_camera, 'Photo Spot'),
                      _buildHighlightChip(Icons.access_time, '24/7 Open'),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // About
                  Text(
                    loc.translate('about_this_place'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    place.localizedDescription(locale),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.8, fontSize: 15),
                  ),
                  const SizedBox(height: 20),

                  // Location map preview
                  Text(
                    loc.translate('location'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (place.price != null && place.price!.trim().isNotEmpty)
                    Text(
                      '${loc.translate('price')}: ${place.price}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  if (place.openingTime != null &&
                      place.openingTime!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${loc.translate('opening_time')}: ${place.openingTime}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  if (place.website != null && place.website!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () => _openWebsite(context),
                        child: Text(
                          place.website!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                decoration: TextDecoration.underline,
                                color: Theme.of(context).primaryColor,
                              ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          center: LatLng(place.latitude, place.longitude),
                          zoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(place.latitude, place.longitude),
                                width: 40,
                                height: 40,
                                builder: (ctx) => const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            place.location,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showAddComment(context),
                          child: Text(loc.translate('add_comment')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openDirections(context),
                          child: Text(loc.translate('get_directions')),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Rating + reviews
                  Text(
                    loc.translate('rating'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(place.rating.toStringAsFixed(1)),
                      const SizedBox(width: 12),
                      Consumer<PlaceProvider>(
                        builder: (context, provider, _) {
                          final p = provider.places.firstWhere(
                            (e) => e.id == place.id,
                            orElse: () => place,
                          );
                          final reviewCount = p.comments.isNotEmpty
                              ? p.comments.length
                              : p.commentCount;
                          return Text(
                            '($reviewCount reviews)',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Consumer<PlaceProvider>(
                    builder: (context, provider, _) {
                      final p = provider.places.firstWhere(
                        (e) => e.id == place.id,
                        orElse: () => place,
                      );
                      if (p.comments.isEmpty)
                        return Text(loc.translate('no_reviews_yet'));
                      return Column(
                        children: p.comments.reversed.map((c) {
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                c.author.isNotEmpty ? c.author[0] : '?',
                              ),
                            ),
                            title: Row(
                              children: [
                                for (int i = 0; i < c.rating; i++)
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                              ],
                            ),
                            subtitle: Text(c.text),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
