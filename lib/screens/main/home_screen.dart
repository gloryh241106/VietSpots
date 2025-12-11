import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/screens/main/search_screen.dart';
import 'package:vietspots/utils/mock_data.dart';
import 'package:vietspots/widgets/place_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<LocalizationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VietSpots'),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Có thể bạn sẽ thích'),
              _buildHorizontalList(MockDataService.places),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Các địa điểm gần bạn'),
              _buildHorizontalList(MockDataService.district12Places),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Các địa điểm bạn đã đi'),
              _buildHorizontalList(MockDataService.places.reversed.toList()),
            ],
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
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHorizontalList(List places) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: places.length,
        itemBuilder: (context, index) {
          return PlaceCard(place: places[index]);
        },
      ),
    );
  }
}
