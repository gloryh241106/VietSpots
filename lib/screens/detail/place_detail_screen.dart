import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
// dart:typed_data is not needed; `Uint8List` is available via foundation
import 'package:provider/provider.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/detail/directions_map_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/utils/typography.dart';
import 'package:vietspots/utils/trackasia.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vietspots/services/comment_service.dart';
import 'package:vietspots/services/api_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vietspots/services/image_service.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  final bool openComments;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.openComments = false,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  List<PlaceComment> _localComments = [];
  final int _commentsLimit = 10;
  int _commentsOffset = 0;
  bool _hasMoreComments = false;
  bool _isLoadingMore = false;
  final GlobalKey _commentsSectionKey = GlobalKey();
  // Toggle to show per-chip icons (true = show small icons in chips)
  final bool _showChipIcons = true;
  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      // If the Place object already contains comments (e.g. created from Chat DTO),
      // prefer using those immediately to avoid extra network calls.
      if (widget.place.comments.isNotEmpty) {
        final provider = Provider.of<PlaceProvider>(context, listen: false);
        final contains = provider.places.any((p) => p.id == widget.place.id);
        if (contains) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.setComments(
              widget.place.id,
              widget.place.comments,
              replaceCount: true,
            );
          });
        } else {
          setState(() {
            _localComments = widget.place.comments;
          });
        }
        return;
      }

      final api = Provider.of<ApiService>(context, listen: false);
      final service = CommentService(api);
      // Load first page (10 comments) for detail view
      final dtos = await service.getPlaceComments(
        widget.place.id,
        limit: _commentsLimit,
        offset: 0,
      );
      final comments = dtos.map((d) => d.toPlaceComment()).toList();
      _commentsOffset = comments.length;
      // Determine if there's likely more comments on server
      _hasMoreComments =
          (widget.place.ratingCount ?? widget.place.commentCount) >
          _commentsOffset;
      if (mounted) {
        final provider = Provider.of<PlaceProvider>(context, listen: false);
        final contains = provider.places.any((p) => p.id == widget.place.id);
        if (contains) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.setComments(widget.place.id, comments, replaceCount: true);
          });
        } else {
          // Place not present in provider lists (e.g. came from Chat suggestions).
          // Keep comments locally so this screen can display them.
          setState(() {
            _localComments = comments;
          });
          // If this screen was opened requesting comments, scroll to comments
          if (widget.openComments) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                if (_commentsSectionKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    _commentsSectionKey.currentContext!,
                    duration: const Duration(milliseconds: 400),
                    alignment: 0.1,
                  );
                }
              } catch (_) {}
            });
          }
        }
      }
      // Fallback: if backend reports reviews but we got no items, retry with larger limit
      final backendCount =
          widget.place.ratingCount ?? widget.place.commentCount;
      if (comments.isEmpty && backendCount > 0) {
        try {
          final retryLimit = backendCount.clamp(5, 200).toInt();
          final dtos2 = await service.getPlaceComments(
            widget.place.id,
            limit: retryLimit,
          );
          final comments2 = dtos2.map((d) => d.toPlaceComment()).toList();
          if (mounted && comments2.isNotEmpty) {
            final provider = Provider.of<PlaceProvider>(context, listen: false);
            final contains = provider.places.any(
              (p) => p.id == widget.place.id,
            );
            if (contains) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                provider.setComments(
                  widget.place.id,
                  comments2,
                  replaceCount: true,
                );
              });
            } else {
              setState(() {
                _localComments = comments2;
                _commentsOffset = comments2.length;
                _hasMoreComments =
                    (widget.place.ratingCount ?? widget.place.commentCount) >
                    _commentsOffset;
              });
            }
            if (widget.openComments) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  if (_commentsSectionKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _commentsSectionKey.currentContext!,
                      duration: const Duration(milliseconds: 400),
                      alignment: 0.1,
                    );
                  }
                } catch (_) {}
              });
            }
          }
        } catch (e) {
          debugPrint('Retry fetch comments failed for ${widget.place.id}: $e');
        }
      }
    } catch (e) {
      // Silently ignore
      debugPrint('Failed to load comments: $e');
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final service = CommentService(api);
      // Capture provider before awaiting network calls to avoid using
      // `context` after an await.
      final provider = Provider.of<PlaceProvider>(context, listen: false);
      final dtos = await service.getPlaceComments(
        widget.place.id,
        limit: _commentsLimit,
        offset: _commentsOffset,
      );
      final more = dtos.map((d) => d.toPlaceComment()).toList();
      if (more.isNotEmpty) {
        // Append to existing displayed comments
        final contains = provider.places.any((p) => p.id == widget.place.id);
        if (contains) {
          // Get current comments from provider
          final p = provider.places.firstWhere(
            (p) => p.id == widget.place.id,
            orElse: () => widget.place,
          );
          final merged = [...p.comments, ...more];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.setComments(widget.place.id, merged, replaceCount: true);
          });
        } else {
          setState(() {
            _localComments = [..._localComments, ...more];
          });
        }

        _commentsOffset += more.length;
        final backendCount =
            widget.place.ratingCount ?? widget.place.commentCount;
        _hasMoreComments = backendCount > _commentsOffset;
      } else {
        _hasMoreComments = false;
      }
    } catch (e) {
      debugPrint('Failed to load more comments: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // Note: manual refresh button removed from UI; comments reloads happen
  // when provider data updates or when the screen is re-opened.

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

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationProvider>(context);
    final locale = loc.locale.languageCode;
    return Scaffold(
      // Pull-to-refresh for the whole details page. Mirrors HomeScreen's
      // behaviour: refresh global place data then update comments.
      body: RefreshIndicator(
        onRefresh: () async {
          final provider = Provider.of<PlaceProvider>(context, listen: false);
          await provider.refresh();
          await _loadComments();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                // Ensure title has enough left inset so it doesn't get
                // clipped by the leading/back button when collapsed.
                // Add right padding so title doesn't overlap action icons
                // when the app bar is collapsed.
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 72,
                  end: 88,
                  bottom: 16,
                ),
                title: Text(
                  widget.place.localizedName(locale),
                  style: AppTypography.heading2.copyWith(
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.place.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) =>
                          Container(color: Colors.grey[300]),
                    ),
                    Container(color: Colors.black26),
                  ],
                ),
              ),
              actions: [
                Consumer<PlaceProvider>(
                  builder: (context, placeProvider, _) {
                    final isFav = placeProvider.isFavorite(widget.place.id);
                    return IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 28,
                      ),
                      onPressed: () async {
                        // Capture messenger and messages before any awaits to avoid
                        // using BuildContext across async gaps.
                        final messenger = ScaffoldMessenger.of(context);
                        if (!placeProvider.favoritesEnabled) {
                          // Server-side favorites are unavailable (missing table).
                          // Allow a local-only toggle so UI remains responsive,
                          // but inform the user the change won't be persisted.
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                loc.translate('favorites_unavailable'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }

                        final auth = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        if (!auth.isLoggedIn) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                loc.translate('please_login_to_favorite'),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        // Capture the label strings before awaiting network calls.
                        final addedMsg = loc.translate('added_to_favorites');
                        final removedMsg = loc.translate(
                          'removed_from_favorites',
                        );

                        await placeProvider.toggleFavorite(widget.place.id);
                        final nowFav = placeProvider.isFavorite(
                          widget.place.id,
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(nowFav ? addedMsg : removedMsg),
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
                                style: AppTypography.titleLarge,
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
                            final topCount = (p.ratingCount ?? 0) > 0
                                ? (p.ratingCount ?? 0)
                                : p.commentCount;
                            return Text(
                              '($topCount ${loc.translate('reviews')})',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // About
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.translate('about_this_place'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAboutSection(
                      widget.place.localizedDescription(locale),
                    ),
                    const SizedBox(height: 20),

                    // Opening time heading (move 'Location' label to map section)
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.translate('opening_time'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (widget.place.price != null &&
                        widget.place.price!.trim().isNotEmpty)
                      Text(
                        '${loc.translate('price')}: ${widget.place.price}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    if (widget.place.openingTime != null &&
                        widget.place.openingTime!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      // Compact two-column layout for opening times.
                      Builder(
                        builder: (context) {
                          final raw = widget.place.openingTime!.trim();
                          final lines = raw
                              .split('\n')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                          // Single-line (or simple) value: render as-is but emphasize times.
                          if (lines.length <= 1) {
                            final theme = Theme.of(context);
                            final base = theme.textTheme.bodyLarge;
                            final hasDigit = RegExp(r'\d').hasMatch(raw);
                            return Text(
                              raw,
                              style: hasDigit
                                  ? base?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          theme.textTheme.bodyLarge?.color ??
                                          Colors.black87,
                                    )
                                  : base,
                            );
                          }

                          final half = (lines.length / 2).ceil();
                          final left = lines.sublist(0, half);
                          final right = lines.sublist(half);

                          // Determine today's label in Vietnamese (PlaceService uses these)
                          final now = DateTime.now();
                          final dayOrder = [
                            'Thứ Hai',
                            'Thứ Ba',
                            'Thứ Tư',
                            'Thứ Năm',
                            'Thứ Sáu',
                            'Thứ Bảy',
                            'Chủ Nhật',
                          ];
                          final todayLabel = dayOrder[(now.weekday - 1) % 7];

                          bool? isOpenNowFromTime(String timeText) {
                            final t = timeText.trim().toLowerCase();
                            if (t.isEmpty) return null;
                            if (t.contains('all') ||
                                t.contains('all day') ||
                                t.contains('24')) {
                              return true;
                            }
                            if (t.contains('closed') ||
                                t.contains('đóng') ||
                                t.contains('off')) {
                              return false;
                            }

                            // Extract all time ranges (accept hyphen, en-dash, em-dash)
                            final rangeRegex = RegExp(
                              r"(\d{1,2}:?\d{0,2})\s*[\-–—−]\s*(\d{1,2}:?\d{0,2})",
                            );
                            final matches = rangeRegex
                                .allMatches(timeText)
                                .toList();
                            if (matches.isEmpty) return null;

                            String parsePart(String s) {
                              return s.replaceAll(' ', '');
                            }

                            int toMinutes(String part) {
                              final p = part.split(':');
                              try {
                                final h = int.parse(p[0]);
                                final m = p.length > 1 && p[1].isNotEmpty
                                    ? int.parse(p[1])
                                    : 0;
                                return h * 60 + m;
                              } catch (_) {
                                return -1;
                              }
                            }

                            final nowMin = now.hour * 60 + now.minute;
                            // If any range contains 'now', consider it open. If ranges parsed but none match, return false.
                            var foundValidRange = false;
                            for (final m in matches) {
                              final startRaw = parsePart(m.group(1)!);
                              final endRaw = parsePart(m.group(2)!);
                              final start = toMinutes(startRaw);
                              final end = toMinutes(endRaw);
                              if (start < 0 || end < 0) continue;
                              foundValidRange = true;
                              if (end > start) {
                                if (nowMin >= start && nowMin <= end) {
                                  return true;
                                }
                              } else {
                                // Overnight range
                                if (nowMin >= start || nowMin <= end) {
                                  return true;
                                }
                              }
                            }
                            return foundValidRange ? false : null;
                          }

                          // For single-line raw values, try to decide open state
                          final singleIsOpen = isOpenNowFromTime(raw);

                          Widget rowItem(String line) {
                            final parts = line.split(':');
                            final day = parts.length > 1 ? parts.first : '';
                            final time = parts.length > 1
                                ? parts.sublist(1).join(':').trim()
                                : line;
                            // Determine if this row represents today
                            final isToday =
                                day.trim().toLowerCase() ==
                                todayLabel.toLowerCase();
                            final inferredOpen = isOpenNowFromTime(time);
                            Color timeColor =
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                Colors.black87;
                            if (isToday) {
                              if (inferredOpen == true) {
                                timeColor = Colors.green;
                              } else if (inferredOpen == false) {
                                timeColor = Colors.red;
                              } else if (singleIsOpen == true) {
                                timeColor = Colors.green;
                              } else if (singleIsOpen == false) {
                                timeColor = Colors.red;
                              }
                            }
                            final timeStyle = Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: timeColor,
                                );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      day,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: (() {
                                      // Split multiple ranges (comma/;//) into separate lines
                                      final ranges = time
                                          .split(RegExp(r',|;|/'))
                                          .map((s) => s.trim())
                                          .where((s) => s.isNotEmpty)
                                          .toList();
                                      if (ranges.length <= 1) {
                                        return Text(
                                          time,
                                          textAlign: TextAlign.right,
                                          style: timeStyle,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: ranges.map((r) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2.0,
                                            ),
                                            child: Text(
                                              r,
                                              textAlign: TextAlign.right,
                                              style: timeStyle,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    })(),
                                  ),
                                ],
                              ),
                            );
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 420;
                              final allLines = [...left, ...right];
                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: allLines
                                      .map((l) => rowItem(l))
                                      .toList(),
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: left
                                          .map((l) => rowItem(l))
                                          .toList(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: right
                                          .map((l) => rowItem(l))
                                          .toList(),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],

                    // Website: promoted to its own top-level section
                    if (widget.place.website != null &&
                        widget.place.website!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.public,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            // Ensure the Website heading starts with a capital letter
                            () {
                              final l = Provider.of<LocalizationProvider>(
                                context,
                                listen: false,
                              ).translate('website');
                              if (l.trim().isEmpty) return 'Website';
                              return l[0].toUpperCase() + l.substring(1);
                            }(),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
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
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),

                    // Location map preview label
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.translate('location'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // MAP PREVIEW
                    // Using OpenStreetMap public tile servers here as the
                    // default raster tile provider. OSM is free to use for
                    // development and small projects, but please review the
                    // OSM Tile Usage Policy for production use:
                    // https://operations.osmfoundation.org/policies/tiles
                    //
                    // Important: OSM requests should include a proper
                    // User-Agent identifying your application. The
                    // `flutter_map` package provides `TileLayer.userAgentPackageName`
                    // to set this. Consider setting it to your app's package
                    // name before publishing.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              widget.place.latitude,
                              widget.place.longitude,
                            ),
                            initialZoom: 14.0,
                          ),
                          children: [
                            TileLayer(
                              // TrackAsia tiles. Template comes from `.env` via
                              // `TRACKASIA_TILE_TEMPLATE`, or is built from
                              // `TRACKASIA_API_KEY`. See `trackAsiaTileUrl()`.
                              urlTemplate: trackAsiaTileUrl(),
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
                                  child: const Icon(
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
                            final topCount = (p.ratingCount ?? 0) > 0
                                ? (p.ratingCount ?? 0)
                                : p.commentCount;
                            return Text(
                              '($topCount ${loc.translate('reviews')})',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Simplified comments rendering to avoid deep nesting and parsing issues
                    Container(
                      key: _commentsSectionKey,
                      child: Consumer<PlaceProvider>(
                        builder: (context, provider, _) {
                          final p = provider.places.firstWhere(
                            (e) => e.id == widget.place.id,
                            orElse: () => widget.place,
                          );
                          var commentsToShow = p.comments.isNotEmpty
                              ? p.comments
                              : _localComments;
                          // Do not truncate comments in the detail screen —
                          // always show what we have and let pagination handle loading more.
                          if (commentsToShow.isEmpty) {
                            return Text(loc.translate('no_reviews_yet'));
                          }
                          final backendCount = p.ratingCount ?? p.commentCount;
                          final canLoadMore =
                              _hasMoreComments ||
                              backendCount > commentsToShow.length;
                          return Column(
                            children: [
                              ...commentsToShow.reversed.map((c) {
                                // Build star row (5 stars, filled up to c.rating)
                                final stars = List<Widget>.generate(5, (i) {
                                  final idx = i + 1;
                                  final filled = idx <= c.rating;
                                  return Icon(
                                    Icons.star,
                                    color: filled
                                        ? Colors.amber
                                        : Colors.grey[300],
                                    size: 16,
                                  );
                                });

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            child: Text(
                                              c.author.isNotEmpty
                                                  ? c.author[0]
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.author.isNotEmpty
                                                      ? c.author
                                                      : 'Anonymous',
                                                  style:
                                                      AppTypography.titleMedium,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(children: stars),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(c.text),
                                      const SizedBox(height: 8),
                                      if (c.imagePath != null)
                                        Builder(
                                          builder: (_) {
                                            final url = c.imagePath!;
                                            if (url.startsWith('http') ||
                                                url.startsWith('data:')) {
                                              return SizedBox(
                                                height: 160,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: CachedNetworkImage(
                                                    imageUrl: url,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    placeholder: (c, u) =>
                                                        Container(
                                                          color:
                                                              Colors.grey[200],
                                                        ),
                                                    errorWidget: (c, u, e) =>
                                                        Container(
                                                          color:
                                                              Colors.grey[200],
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                            try {
                                              final f = File(url);
                                              return SizedBox(
                                                height: 160,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    f,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                  ),
                                                ),
                                              );
                                            } catch (_) {
                                              return const SizedBox.shrink();
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              if (canLoadMore)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _isLoadingMore
                                          ? null
                                          : _loadMoreComments,
                                      child: _isLoadingMore
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              Provider.of<LocalizationProvider>(
                                                context,
                                                listen: false,
                                              ).translate('home.load_more'),
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(String raw) {
    final parsed = _tryParseMapLikeString(raw);
    if (parsed is Map<String, dynamic>) {
      // Filter out entries that have no renderable content (e.g. all flags=false)
      final entries = parsed.entries
          .where((e) => _hasRenderableValue(e.value))
          .toList();

      if (entries.isEmpty) {
        return const SizedBox.shrink();
      }

      // Render map-style groups as collapsible sections with counts
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final rawKey = e.key.toString();
          final val = e.value;
          final norm = _normalizeGroupKey(rawKey);
          final loc = Provider.of<LocalizationProvider>(context, listen: false);
          final translated = loc.translate(norm);
          final displayLabel =
              (translated.trim().isEmpty ||
                  translated == norm ||
                  translated.contains('_'))
              ? _humanizeKey(norm)
              : translated;
          final headingIcon = _iconForGroup(norm);
          final count = _countRenderableItems(val);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // Hide the default trailing chevron; use count inline instead
                trailing: const SizedBox.shrink(),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(
                  left: 0,
                  right: 0,
                  bottom: 8,
                ),
                initiallyExpanded: true,
                title: Row(
                  children: [
                    if (headingIcon != null) ...[
                      Icon(headingIcon, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        displayLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${count.toString()})',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (headingIcon != null) const SizedBox(width: 26),
                      Expanded(child: _renderValue(val)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    // Fallback: raw text
    // Try to extract labeled bullet sections (format produced by PlaceDTO._formatAboutMap)
    final parsedFormatted = _parseFormattedAboutText(raw);
    final description = parsedFormatted['description'] as String?;
    final groups = parsedFormatted['groups'] as Map<String, List<String>>?;

    if (groups != null && groups.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description.trim().isNotEmpty) ...[
            SelectableText(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          // Render each group as a collapsible section with chips
          ...groups.entries.map((entry) {
            final rawLabel = entry.key;
            final items = entry.value;
            // skip empty groups
            final nonEmptyItems = items
                .where((it) => it.toString().trim().isNotEmpty)
                .toList();
            if (nonEmptyItems.isEmpty) return const SizedBox.shrink();
            final norm = _normalizeGroupKey(rawLabel);
            final loc = Provider.of<LocalizationProvider>(
              context,
              listen: false,
            );
            final translated = loc.translate(norm);
            final displayLabel =
                (translated.trim().isEmpty ||
                    translated == norm ||
                    translated.contains('_'))
                ? _humanizeKey(norm)
                : translated;
            final headingIcon = _iconForGroup(norm);

            final count = nonEmptyItems.length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(
                    left: 0,
                    right: 0,
                    bottom: 8,
                  ),
                  initiallyExpanded: true,
                  title: Row(
                    children: [
                      if (headingIcon != null) ...[
                        Icon(headingIcon, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          displayLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${count.toString()})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (headingIcon != null) const SizedBox(width: 26),
                        Expanded(child: _buildAmenityChips(nonEmptyItems)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return SelectableText(
      raw,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(height: 1.8, fontSize: 15),
    );
  }

  /// Parse formatted about text produced by backend formatter into groups.
  /// Example input:
  /// "🏠 Tiện nghi\n• Toilet\n• Parking\n\n♿ Tiếp cận\n• Wheelchair"
  /// Returns { 'description': String?, 'groups': {label: [items...] } }
  Map<String, dynamic> _parseFormattedAboutText(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return {'description': null, 'groups': <String, List<String>>{}};
    }

    final descriptionBuffer = <String>[];
    final Map<String, List<String>> groups = {};
    String? currentLabel;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('•') || line.startsWith('-')) {
        final cleaned = line.replaceFirst(RegExp(r'^[•\-]\s*'), '');
        if (cleaned.isEmpty) continue;
        final label = currentLabel ?? 'Other';
        groups.putIfAbsent(label, () => []).add(cleaned);
      } else if (RegExp(r'^([^:]+):\s*(.+)\$').hasMatch(line)) {
        // key: value lines (e.g. "Nhà vệ sinh: true")
        final m = RegExp(r'^([^:]+):\s*(.+)\$').firstMatch(line);
        if (m != null) {
          final k = m.group(1)!.trim();
          final rawVal = m.group(2)!.trim();
          final valLower = rawVal.toLowerCase();
          final isTrue =
              valLower == 'true' || valLower == 'yes' || valLower == '1';
          final isFalse =
              valLower == 'false' || valLower == 'no' || valLower == '0';
          if (isTrue) {
            final labelName = currentLabel ?? 'Amenities';
            groups.putIfAbsent(labelName, () => []).add(k);
          } else if (!isFalse) {
            // non-boolean value -> include as descriptive string under Details
            final labelName = currentLabel ?? 'Details';
            groups.putIfAbsent(labelName, () => []).add('$k: $rawVal');
          }
        }
      } else if (RegExp(r'^[\p{So}\p{Sc}]', unicode: true).hasMatch(line)) {
        // Label line that starts with an emoji or symbol
        // Remove leading emoji/symbols for display
        final cleaned = line
            .replaceAll(RegExp(r'^[\p{So}\p{Sc}]\s*'), '')
            .trim();
        currentLabel = cleaned.isNotEmpty ? cleaned : 'Other';
        groups.putIfAbsent(currentLabel, () => []);
      } else {
        // Plain paragraph — treat as description unless it's a short label
        if (line.contains(':') || line.length > 40 || i == 0) {
          descriptionBuffer.add(line);
        } else {
          // short line — treat as a label
          currentLabel = line;
          groups.putIfAbsent(currentLabel, () => []);
        }
      }
    }

    return {
      'description': descriptionBuffer.isNotEmpty
          ? descriptionBuffer.join('\n\n')
          : null,
      'groups': groups,
    };
  }

  Widget _renderValue(dynamic v) {
    if (v == null) {
      return const Text('-');
    }

    // Simple scalar values
    if (v is String) {
      return Text(v, style: Theme.of(context).textTheme.bodyLarge);
    }
    if (v is num || v is bool) {
      return Text(v.toString(), style: Theme.of(context).textTheme.bodyLarge);
    }

    // List of simple values -> render as chips if possible
    if (v is List) {
      final simpleStrings = v
          .where((it) => it == null || it is String || it is num || it is bool)
          .map((it) => it?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (simpleStrings.isNotEmpty) {
        return _buildAmenityChips(simpleStrings);
      }

      // Fallback to bullet list for complex items
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: v
            .map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '• ${it.toString()}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
            .toList(),
      );
    }

    // Map -> if it's a simple map of flags or strings, render chips
    if (v is Map) {
      // Map of bools (e.g. {'Toilet': true, 'Wheelchair': false})
      final map = Map<String, dynamic>.from(v);
      final trueKeys = <String>[];
      final simpleStrings = <String>[];
      map.forEach((k, val) {
        if (val is bool && val == true) {
          trueKeys.add(_humanizeKey(k));
        } else if (val is String && val.trim().isNotEmpty) {
          simpleStrings.add(val.trim());
        }
      });

      final chips = <String>[];
      chips.addAll(trueKeys);
      chips.addAll(simpleStrings);

      if (chips.isNotEmpty) {
        return _buildAmenityChips(chips);
      }

      // Fallback: show key: value lines
      final fallback = map.entries
          .where((kv) {
            final val = kv.value;
            if (val == null) return false;
            if (val is bool) return false; // skip boolean flags (false)
            if (val is String && val.trim().isEmpty) return false;
            if (val is List && val.isEmpty) return false;
            if (val is Map && val.isEmpty) return false;
            return true;
          })
          .map(
            (kv) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '${_humanizeKey(kv.key.toString())}: ${kv.value}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
          .toList();

      if (fallback.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fallback,
      );
    }

    return Text(v.toString(), style: Theme.of(context).textTheme.bodyLarge);
  }

  Widget _buildAmenityChips(List<String> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (t) =>
                _amenityChip(t, icon: _showChipIcons ? _iconForLabel(t) : null),
          )
          .toList(),
    );
  }

  Widget _amenityChip(String label, {IconData? icon}) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : const Color(0xFFF7ECEC);
    final screen = MediaQuery.of(context).size.width;
    final maxTextWidth = screen * 0.72; // leave room for icon + padding
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            SizedBox(
              width: 20,
              child: Center(
                child: Icon(icon, size: 16, color: Colors.redAccent),
              ),
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTextWidth),
            child: Text(
              label,
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLabel(String label) {
    final s = label.toLowerCase();
    if (s.contains('toilet') ||
        s.contains('nhà vệ sinh') ||
        s.contains('vệ sinh')) {
      return Icons.wc;
    }
    if (s.contains('parking') || s.contains('đỗ xe') || s.contains('bãi')) {
      return Icons.local_parking;
    }
    if (s.contains('wheelchair') ||
        s.contains('xe lăn') ||
        s.contains('tiếp cận') ||
        s.contains('accessible')) {
      return Icons.accessible;
    }
    if (s.contains('trẻ em') || s.contains('child')) {
      return Icons.child_care;
    }
    if (s.contains('giao') || s.contains('delivery')) {
      return Icons.local_shipping;
    }
    if (s.contains('ăn') || s.contains('ăn tại') || s.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (s.contains('mang')) {
      return Icons.takeout_dining;
    }
    if (s.contains('đặt') || s.contains('booking') || s.contains('nhận đặt')) {
      return Icons.event_available;
    }
    if (s.contains('cà phê') || s.contains('coffee')) {
      return Icons.local_cafe;
    }
    if (s.contains('photo') || s.contains('photo spot') || s.contains('ảnh')) {
      return Icons.photo_camera;
    }
    if (s.contains('24/7') || s.contains('24/7') || s.contains('open')) {
      return Icons.access_time;
    }
    if (s.contains('wifi')) {
      return Icons.wifi;
    }
    if (s.contains('nhóm') || s.contains('group')) {
      return Icons.groups;
    }
    if (s.contains('ngoài trời') || s.contains('outdoor')) {
      return Icons.outdoor_grill;
    }
    if (s.contains('shop') || s.contains('mua')) {
      return Icons.shopping_cart;
    }
    if (s.contains('breakfast') || s.contains('bữa sáng')) {
      return Icons.breakfast_dining;
    }
    if (s.contains('dessert') || s.contains('tráng miệng')) {
      return Icons.icecream;
    }
    return Icons.send;
  }

  /// Map canonical group keys to icons (used for group headings)
  IconData? _iconForGroup(String canonicalKey) {
    switch (canonicalKey) {
      case 'parking':
        return Icons.local_parking;
      case 'amenities':
        return Icons.home;
      case 'accessibility':
        return Icons.accessible;
      case 'payments':
        return Icons.payment;
      case 'planning':
        return Icons.event_available;
      case 'dining_options':
        return Icons.restaurant;
      case 'service_options':
        return Icons.room_service;
      case 'highlights':
        return Icons.star;
      case 'details':
        return Icons.info;
      default:
        return null;
    }
  }

  /// Normalize various raw group labels (English/Vietnamese) to canonical keys
  String _normalizeGroupKey(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('park') ||
        s.contains('đỗ xe') ||
        s.contains('parking') ||
        s.contains('bãi')) {
      return 'parking';
    }
    if (s.contains('amenit') || s.contains('tiện') || s.contains('tiện nghi')) {
      return 'amenities';
    }
    if (s.contains('access') ||
        s.contains('tiếp cận') ||
        s.contains('wheelchair')) {
      return 'accessibility';
    }
    if (s.contains('payment') ||
        s.contains('thanh toán') ||
        s.contains('payments')) {
      return 'payments';
    }
    if (s.contains('plan') || s.contains('đặt chỗ') || s.contains('planning')) {
      return 'planning';
    }
    if (s.contains('dining') || s.contains('phục vụ') || s.contains('ăn')) {
      return 'dining_options';
    }
    if (s.contains('service') || s.contains('dịch vụ')) {
      return 'service_options';
    }
    if (s.contains('highlight') ||
        s.contains('điểm nổi bật') ||
        s.contains('highlights')) {
      return 'highlights';
    }
    if (s.contains('detail') || s.contains('chi tiết')) {
      return 'details';
    }
    // fallback to raw lowercased label
    return raw;
  }

  String _humanizeKey(String key) {
    // Simple humanization: replace underscores, camelCase -> words, capitalize
    var s = key.replaceAll('_', ' ');
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  dynamic _tryParseMapLikeString(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      if (s.startsWith('{') || s.startsWith('[')) {
        try {
          return json.decode(s);
        } catch (_) {
          var norm = s.replaceAll("'", '"');
          norm = norm
              .replaceAll('True', 'true')
              .replaceAll('False', 'false')
              .replaceAll('None', 'null');
          return json.decode(norm);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _hasRenderableValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is bool) return v == true;
    if (v is num) return true;
    if (v is List) {
      return v
          .where((it) => it != null && it.toString().trim().isNotEmpty)
          .isNotEmpty;
    }
    if (v is Map) {
      final map = Map<String, dynamic>.from(v);
      for (final kv in map.entries) {
        final val = kv.value;
        if (val == null) continue;
        if (val is bool && val == true) return true;
        if (val is String && val.trim().isNotEmpty) return true;
        if (val is num) return true;
        if (val is List && val.isNotEmpty) return true;
        if (val is Map && val.isNotEmpty) return true;
      }
      return false;
    }
    return v.toString().trim().isNotEmpty;
  }

  int _countRenderableItems(dynamic v) {
    if (v == null) return 0;
    if (v is String) return v.trim().isEmpty ? 0 : 1;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return 1;
    if (v is List) {
      return v
          .where((it) => it != null && it.toString().trim().isNotEmpty)
          .length;
    }
    if (v is Map) {
      final map = Map<String, dynamic>.from(v);
      var total = 0;
      for (final kv in map.entries) {
        final val = kv.value;
        if (val == null) continue;
        if (val is bool && val == true) {
          total += 1;
        } else if (val is String && val.trim().isNotEmpty) {
          total += 1;
        } else if (val is num) {
          total += 1;
        } else if (val is List) {
          total += val
              .where((it) => it != null && it.toString().trim().isNotEmpty)
              .length;
        } else if (val is Map) {
          total += _countRenderableItems(val);
        }
      }
      return total;
    }
    return v.toString().trim().isEmpty ? 0 : 1;
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
  final List<XFile> _images = [];
  final List<Uint8List> _imageBytes = [];
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Offer Camera or Gallery. Keep sheet safe from navigation bar.
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(
                  Provider.of<LocalizationProvider>(
                    context,
                    listen: false,
                  ).translate('gallery'),
                ),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(
                  Provider.of<LocalizationProvider>(
                    context,
                    listen: false,
                  ).translate('camera'),
                ),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(
                  Provider.of<LocalizationProvider>(
                    context,
                    listen: false,
                  ).translate('cancel'),
                ),
                onTap: () => Navigator.pop(ctx, null),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    try {
      final loc = Provider.of<LocalizationProvider>(context, listen: false);
      if (choice == 'camera') {
        final status = await Permission.camera.request();
        if (!mounted) return;
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.translate('photo_permission_denied')),
                action: SnackBarAction(
                  label: loc.translate('open_settings'),
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.translate('photo_permission_denied'))),
          );
          return;
        }

        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _images.add(picked);
          _imageBytes.add(bytes);
        });
      } else {
        // Gallery: request appropriate permission per platform.
        // On newer Android versions Permission.photos (READ_MEDIA_IMAGES) may be available,
        // otherwise fall back to storage.
        PermissionStatus status;
        try {
          if (Platform.isIOS) {
            status = await Permission.photos.request();
          } else {
            // Android: try photos first (modern), then storage
            status = await Permission.photos.request();
            if (!status.isGranted) {
              status = await Permission.storage.request();
            }
          }
        } catch (_) {
          status = await Permission.storage.request();
        }
        if (!mounted) return;
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(loc.translate('photo_permission_denied')),
                action: SnackBarAction(
                  label: loc.translate('open_settings'),
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.translate('photo_permission_denied'))),
          );
          return;
        }

        // Allow multi-select on supported platforms
        try {
          final pickedList = await _picker.pickMultiImage(imageQuality: 75);
          if (pickedList.isNotEmpty) {
            for (final p in pickedList) {
              final bytes = await p.readAsBytes();
              if (!mounted) break;
              _images.add(p);
              _imageBytes.add(bytes);
            }
            if (mounted) setState(() {});
          }
        } catch (_) {
          // Fallback single pick if multi not supported
          final picked = await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 75,
          );
          if (picked == null) return;
          final bytes = await picked.readAsBytes();
          if (!mounted) return;
          setState(() {
            _images.add(picked);
            _imageBytes.add(bytes);
          });
        }
      }
    } catch (e) {
      debugPrint('Image pick failed: $e');
    }
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
      // For local preview store first attached image (data URI on web),
      // backend upload happens asynchronously in `_saveCommentToBackend`.
      imagePath: kIsWeb && _imageBytes.isNotEmpty
          ? 'data:image/${_images.first.name.split('.').last};base64,${base64Encode(_imageBytes.first)}'
          : (_images.isNotEmpty ? _images.first.path : null),
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
    final rootMessenger = ScaffoldMessenger.of(widget.rootContext);
    try {
      // Capture root-level services and messenger before any awaits so we
      // don't reference `widget.rootContext` across async gaps.
      final rootApi = Provider.of<ApiService>(
        widget.rootContext,
        listen: false,
      );
      final service = CommentService(rootApi);
      final imageService = Provider.of<ImageService>(
        widget.rootContext,
        listen: false,
      );
      final rootProvider = Provider.of<PlaceProvider>(
        widget.rootContext,
        listen: false,
      );
      // rootMessenger already captured above

      // Prepare image URLs if there are images
      List<String> imageUrls = [];
      if (_imageBytes.isNotEmpty) {
        try {
          if (kIsWeb) {
            // On web upload from bytes (support multiple)
            final filenames = List.generate(
              _imageBytes.length,
              (i) => _images.length > i ? _images[i].name : 'upload_$i.jpg',
            );
            final uploadResponse = await imageService.uploadImagesFromBytes(
              _imageBytes,
              filenames,
            );
            if (uploadResponse.success) imageUrls.addAll(uploadResponse.urls);
          } else {
            // Mobile: upload from File paths (support multiple)
            final files = _images.map((x) => File(x.path)).toList();
            final uploadResponse = await imageService.uploadImages(files);
            if (uploadResponse.success) imageUrls.addAll(uploadResponse.urls);
          }
        } catch (e) {
          debugPrint('Image upload failed: $e');
        }

        // Additionally, attempt OCR on the first attached image to
        // infer a preferred STT language. Store it in SharedPreferences
        // so push-to-talk transcriptions can use it.
        try {
          final firstBytes = _imageBytes.first;
          final ocrText = await imageService.extractTextFromBytes(firstBytes);
          if (ocrText.isNotEmpty) {
            final detected = imageService.detectLanguageFromText(ocrText);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('preferred_stt_language', detected);
              debugPrint('Saved preferred STT language: $detected');
            } catch (e) {
              debugPrint('Failed to save preferred STT language: $e');
            }
          }
        } catch (e) {
          debugPrint('OCR/detect failed: $e');
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
        // Use the root messenger (from page context) to display results.
        rootMessenger.showSnackBar(
          SnackBar(
            content: Text('Không thể lưu bình luận: ${response.message}'),
          ),
        );
      } else {
        rootMessenger.showSnackBar(
          const SnackBar(content: Text('Bình luận đã được lưu')),
        );
        // Refresh first page of comments from server to get server-side timestamp/images
        try {
          final dtos = await service.getPlaceComments(
            widget.placeId,
            limit: 10,
            offset: 0,
          );
          final comments = dtos.map((d) => d.toPlaceComment()).toList();
          final contains = rootProvider.places.any(
            (p) => p.id == widget.placeId,
          );
          if (contains) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              rootProvider.setComments(
                widget.placeId,
                comments,
                replaceCount: true,
              );
            });
          }
        } catch (e) {
          debugPrint('Failed to refresh comments after create: $e');
        }
      }
    } catch (e) {
      debugPrint('Error saving comment to backend: $e');
      rootMessenger.showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu bình luận: $e')),
      );
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(loc.translate('attach_image')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loc.translate('attach_image_hint'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      if (_imageBytes.isNotEmpty) ...[
                        const SizedBox(height: 12),

                        // Location map preview (labelled 'Location')
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.translate('location'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageBytes.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final bytes = _imageBytes[idx];
                              return Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          insetPadding: const EdgeInsets.all(
                                            12,
                                          ),
                                          child: InteractiveViewer(
                                            panEnabled: true,
                                            minScale: 1.0,
                                            maxScale: 4.0,
                                            child: Image.memory(
                                              bytes,
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 46),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 15,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          bytes,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: 96,
                                                    height: 96,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _images.removeAt(idx);
                                          _imageBytes.removeAt(idx);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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
