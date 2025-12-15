import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/auth_provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/screens/main/search_screen.dart';
import 'package:vietspots/screens/settings/settings_tree.dart';
import 'package:vietspots/utils/mock_data.dart';
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.redAccent,
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
                      ? const Icon(
                          Icons.person,
                          color: Colors.redAccent,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      locProvider.translate('search_hint'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Simulate refresh delay
          await Future.delayed(const Duration(seconds: 1));
          // In real app, reload data from provider/API
        },
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
                _buildHorizontalList(context, MockDataService.places),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  locProvider.translate('nearby_places'),
                ),
                _buildHorizontalList(context, MockDataService.district12Places),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  locProvider.translate('places_you_visited'),
                ),
                _buildHorizontalList(
                  context,
                  MockDataService.places.reversed.toList(),
                ),
              ],
            ),
          ),
        ),
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

  Widget _buildHorizontalList(BuildContext context, List places) {
    // Light background container to make content feel slightly raised.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(230 / 255),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: places.length,
            itemBuilder: (context, index) {
              return PlaceCard(place: places[index]);
            },
          ),
        ),
      ),
    );
  }
}
