import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/detail/place_detail_screen.dart';
import 'package:vietspots/utils/typography.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final double width;

  const PlaceCard({super.key, required this.place, this.width = 200});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = Provider.of<LocalizationProvider>(context);
    final locale = loc.locale.languageCode;
    final placeProvider = Provider.of<PlaceProvider>(context, listen: false);
    final currentPlace = placeProvider.places.firstWhere(
      (p) => p.id == place.id,
      orElse: () => place,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaceDetailScreen(place: place),
          ),
        );
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: isDark ? Border.all(color: Colors.white24, width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(20 / 255),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE + GRADIENT OVERLAY
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: place.imageUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[300]),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),

                // GRADIENT OVERLAY — giúp ảnh đẹp hơn
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(89 / 255),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // CARD CONTENT
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    place.localizedName(locale),
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 17,
                      height: 1.2,
                      color: AppTextColors.primary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // RATING + REVIEWS
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFB300),
                        size: 18,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        place.rating.toString(),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTextColors.primary(context),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        "•",
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTextColors.tertiary(context),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          '${currentPlace.comments.isNotEmpty ? currentPlace.comments.length : currentPlace.commentCount} ${loc.translate('reviews')}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppTextColors.secondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
