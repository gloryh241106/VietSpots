import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
// dart:typed_data is not needed; `Uint8List` is available via foundation
import 'package:provider/provider.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/detail/directions_map_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vietspots/services/comment_service.dart';
import 'package:vietspots/services/api_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vietspots/services/image_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Place place;

  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _loadComments() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final service = CommentService(api);
      final dtos = await service.getPlaceComments(widget.place.id, limit: 20);
      final comments = dtos.map((d) => d.toPlaceComment()).toList();
      if (mounted) {
        Provider.of<PlaceProvider>(
          context,
          listen: false,
        ).setComments(widget.place.id, comments);
      }
    } catch (e) {
      // Silently ignore
      debugPrint('Failed to load comments: $e');
    }
  }

  Future<void> _refreshComments() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang tải bình luận...'),
        duration: Duration(seconds: 1),
      ),
    );
    await _loadComments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _openDirections(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectionsMapScreen(place: widget.place),
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    final url = widget.place.website;
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
    // Use a draggable modal bottom sheet instead of a Dialog.
    // Reason: on Android, Dialog + keyboard often causes bottom overflow or
    // hidden actions on small screens / large text sizes. The sheet + scroll
    // controller is more resilient and easier to debug.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Theme.of(context).dialogTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) =>
          _AddReviewBottomSheet(placeId: widget.place.id, rootContext: context),
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
                widget.place.localizedName(locale),
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
                    imageUrl: widget.place.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[300]),
                  ),
                  Container(color: Colors.black26),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshComments,
                tooltip: 'Làm mới bình luận',
              ),
              Consumer<PlaceProvider>(
                builder: (context, placeProvider, _) {
                  final isFav = placeProvider.isFavorite(widget.place.id);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.redAccent : Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      placeProvider.toggleFavorite(widget.place.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFav
                                ? loc.translate('removed_from_favorites')
                                : loc.translate('added_to_favorites'),
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
                          color: Colors.amber.withValues(alpha: 0.1),
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
                              widget.place.rating.toStringAsFixed(1),
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
                            (e) => e.id == widget.place.id,
                            orElse: () => widget.place,
                          );
                          return Text(
                            '(${p.commentCount} ${loc.translate('reviews')})',
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
                    loc.translate('highlights'),
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
                  SelectableText(
                    widget.place.localizedDescription(locale),
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

                  if (widget.place.price != null &&
                      widget.place.price!.trim().isNotEmpty)
                    Text(
                      '${loc.translate('price')}: ${widget.place.price}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  if (widget.place.openingTime != null &&
                      widget.place.openingTime!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.place.openingTime!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  if (widget.place.website != null &&
                      widget.place.website!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () => _openWebsite(context),
                        child: Text(
                          widget.place.website!,
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
                          center: LatLng(
                            widget.place.latitude,
                            widget.place.longitude,
                          ),
                          zoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://api.trackasia.com/styles/v1/trackasia/streets-v11/tiles/{z}/{x}/{y}?access_token=${dotenv.env['TRACKASIA_API_KEY'] ?? ''}',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  widget.place.latitude,
                                  widget.place.longitude,
                                ),
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
                            widget.place.location,
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
                      Text(widget.place.rating.toStringAsFixed(1)),
                      const SizedBox(width: 12),
                      Consumer<PlaceProvider>(
                        builder: (context, provider, _) {
                          final p = provider.places.firstWhere(
                            (e) => e.id == widget.place.id,
                            orElse: () => widget.place,
                          );
                          return Text(
                            '(${p.commentCount} ${loc.translate('reviews')})',
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
                        (e) => e.id == widget.place.id,
                        orElse: () => widget.place,
                      );
                      if (p.comments.isEmpty) {
                        return Text(loc.translate('no_reviews_yet'));
                      }
                      return Column(
                        children: p.comments.reversed.map((c) {
                          final imagePath = c.imagePath;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                c.author.isNotEmpty ? c.author[0] : '?',
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.author.isNotEmpty
                                        ? c.author
                                        : 'Anonymous',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  _timeAgo(c.timestamp),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    for (int i = 0; i < c.rating; i++)
                                      const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c.text),
                                if (imagePath != null &&
                                    imagePath.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Builder(
                                      builder: (context) {
                                        // imagePath may be a network URL, data URI, or local file path
                                        if (imagePath.startsWith('http')) {
                                          return CachedNetworkImage(
                                            imageUrl: imagePath,
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            placeholder: (c, u) => Container(
                                              height: 160,
                                              color: Colors.grey[200],
                                            ),
                                            errorWidget: (c, u, e) =>
                                                const SizedBox.shrink(),
                                          );
                                        }

                                        if (imagePath.startsWith('data:')) {
                                          try {
                                            final base64Str = imagePath
                                                .split(',')
                                                .last;
                                            final bytes = base64Decode(
                                              base64Str,
                                            );
                                            return Image.memory(
                                              bytes,
                                              height: 160,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            );
                                          } catch (_) {
                                            return const SizedBox.shrink();
                                          }
                                        }

                                        // Fallback: local file (mobile)
                                        try {
                                          return Image.file(
                                            File(imagePath),
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const SizedBox.shrink();
                                                },
                                          );
                                        } catch (_) {
                                          return const SizedBox.shrink();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

class _AddReviewBottomSheet extends StatefulWidget {
  const _AddReviewBottomSheet({
    required this.placeId,
    required this.rootContext,
  });

  final String placeId;
  final BuildContext rootContext;

  @override
  State<_AddReviewBottomSheet> createState() => _AddReviewBottomSheetState();
}

class _AddReviewBottomSheetState extends State<_AddReviewBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int _rating = 5;
  XFile? _image;
  Uint8List? _imageBytes;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Keep a small square preview thumbnail to avoid layout jumps.
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (!mounted || picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = picked;
      _imageBytes = bytes;
    });
  }

  void _submit() {
    final loc = Provider.of<LocalizationProvider>(context, listen: false);
    if (_controller.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }

    final comment = PlaceComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: 'You',
      rating: _rating,
      text: _controller.text.trim(),
      imagePath: kIsWeb && _imageBytes != null
          ? 'data:image/${(_image?.name.split('.').last ?? 'jpg')};base64,${base64Encode(_imageBytes!)}'
          : _image?.path,
      timestamp: DateTime.now(),
    );

    // Add comment locally first
    Provider.of<PlaceProvider>(
      context,
      listen: false,
    ).addComment(widget.placeId, comment);

    // Save comment to Supabase in the background
    _saveCommentToBackend(comment);

    Navigator.pop(context);
    // Use the original page context for SnackBar.
    // The bottom sheet context is disposed immediately after pop.
    if (widget.rootContext.mounted) {
      ScaffoldMessenger.of(
        widget.rootContext,
      ).showSnackBar(SnackBar(content: Text(loc.translate('review_added'))));
    }
  }

  Future<void> _saveCommentToBackend(PlaceComment comment) async {
    try {
      final api = Provider.of<ApiService>(widget.rootContext, listen: false);
      final service = CommentService(api);
      final imageService = Provider.of<ImageService>(
        widget.rootContext,
        listen: false,
      );

      // Prepare image URLs if there's an image
      List<String> imageUrls = [];
      if (_imageBytes != null) {
        try {
          if (kIsWeb) {
            // On web upload from bytes
            final filename = _image?.name ?? 'upload.jpg';
            final uploadResponse = await imageService.uploadImagesFromBytes(
              [_imageBytes!],
              [filename],
            );
            if (uploadResponse.success) imageUrls.addAll(uploadResponse.urls);
          } else {
            // Mobile: upload from File path
            final file = File(_image!.path);
            final uploadResponse = await imageService.uploadImages([file]);
            if (uploadResponse.success) imageUrls.addAll(uploadResponse.urls);
          }
        } catch (e) {
          debugPrint('Image upload failed: $e');
        }
      }

      final response = await service.createComment(
        placeId: widget.placeId,
        authorName: comment.author,
        rating: comment.rating,
        text: comment.text,
        imageUrls: imageUrls,
      );

      if (!response.success) {
        debugPrint('Failed to save comment: ${response.message}');
      } else {
        debugPrint('Comment saved successfully');
      }
    } catch (e) {
      debugPrint('Error saving comment to backend: $e');
    }
  }

  Widget _buildStar(int i) {
    final selected = i <= _rating;
    return IconButton(
      onPressed: () => setState(() => _rating = i),
      icon: Icon(
        selected ? Icons.star : Icons.star_border,
        color: Colors.amber,
      ),
      tooltip: '$i',
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      // Lift the whole sheet above the keyboard to prevent overflow.
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('add_review'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(children: [for (int i = 1; i <= 5; i++) _buildStar(i)]),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: loc.translate('review_hint'),
                          errorText: _showError
                              ? loc.translate('review_required')
                              : null,
                          border: const OutlineInputBorder(),
                        ),
                        minLines: 4,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          onPressed: _pickImage,
                          child: Text(loc.translate('attach_image')),
                        ),
                      ),
                      if (_imageBytes != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _imageBytes!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(loc.translate('cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: Text(loc.translate('submit')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
