import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/main/search_screen.dart';
import 'package:vietspots/screens/settings/settings_tree.dart';
import 'package:vietspots/utils/avatar_image_provider.dart';
import 'package:vietspots/utils/typography.dart';
import 'package:vietspots/widgets/place_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<LocalizationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 0,
        title: Text(
          locProvider.translate('app_name'),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 4.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GeneralInfoScreen(),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarImageProvider(user?.avatarUrl),
                  child: user?.avatarUrl == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchScreen()),
                );
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, color: Theme.of(context).dividerColor),
                    const SizedBox(width: 8),
                    Text(
                      locProvider.translate('search_hint'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<PlaceProvider>(
        builder: (context, placeProvider, child) {
          if (placeProvider.isLoading && placeProvider.places.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (placeProvider.error != null && placeProvider.places.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Không thể tải dữ liệu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => placeProvider.refresh(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => placeProvider.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      locProvider.translate('recommended_for_you'),
                    ),
                    placeProvider.recommendedPlaces.isNotEmpty
                        ? _buildHorizontalList(
                            context,
                            placeProvider.recommendedPlaces,
                          )
                        : _buildEmptyState(context, '🔍 Đang tải địa điểm...'),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      context,
                      locProvider.translate('nearby_places'),
                    ),
                    placeProvider.nearbyPlaces.isNotEmpty
                        ? _buildHorizontalList(
                            context,
                            placeProvider.nearbyPlaces,
                          )
                        : _buildEmptyState(
                            context,
                            '📍 Bật vị trí để xem địa điểm gần bạn',
                            onTap: () async {
                              // Try to request permission or open settings
                              final permission =
                                  await Geolocator.checkPermission();
                              if (permission ==
                                  LocationPermission.deniedForever) {
                                await Geolocator.openAppSettings();
                              } else if (permission ==
                                  LocationPermission.denied) {
                                await Geolocator.requestPermission();
                                // Refresh after granting permission
                                if (context.mounted) {
                                  await placeProvider.refresh();
                                }
                              } else {
                                // Permission granted but no location yet
                                await Geolocator.openLocationSettings();
                              }
                            },
                          ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      context,
                      locProvider.translate('places_you_visited'),
                    ),
                    placeProvider.visitedPlaces.isNotEmpty
                        ? _buildHorizontalList(
                            context,
                            placeProvider.visitedPlaces,
                          )
                        : _buildEmptyState(
                            context,
                            '🗺️ Bạn chưa đến địa điểm nào',
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: AppTypography.sectionHeader.copyWith(
          color: AppTextColors.primary(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String message, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Nhấn để cấp quyền',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, List places) {
    return HorizontalPlacesCarousel(places: places);
  }
}

class HorizontalPlacesCarousel extends StatefulWidget {
  const HorizontalPlacesCarousel({super.key, required this.places});

  final List places;

  @override
  State<HorizontalPlacesCarousel> createState() =>
      _HorizontalPlacesCarouselState();
}

class _HorizontalPlacesCarouselState extends State<HorizontalPlacesCarousel> {
  final ScrollController _controller = ScrollController();

  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  double get _scrollStep => 240.0; // approximate card width + spacing

  void _scrollTo(double offset) {
    final target = offset.clamp(
      0.0,
      _controller.position.hasContentDimensions
          ? _controller.position.maxScrollExtent
          : double.infinity,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _updateNavVisibility() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final off = _controller.offset;
    final canLeft = off > 8.0; // small epsilon
    final canRight = off < (max - 8.0);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateNavVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateNavVisibility);
    // ensure initial visibility after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateNavVisibility());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 230 / 255),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.places.length,
                itemBuilder: (context, index) {
                  return PlaceCard(place: widget.places[index]);
                },
              ),
              if (kIsWeb) ...[
                if (_canScrollLeft)
                  Positioned(
                    left: 8,
                    child: _NavButton(
                      icon: Icons.chevron_left,
                      onTap: () => _scrollTo(_controller.offset - _scrollStep),
                    ),
                  ),
                if (_canScrollRight)
                  Positioned(
                    right: 8,
                    child: _NavButton(
                      icon: Icons.chevron_right,
                      onTap: () => _scrollTo(_controller.offset + _scrollStep),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 40 / 255),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
