import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/detail/place_detail_screen.dart';

import 'package:vietspots/services/place_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Place> _filteredPlaces = [];

  @override
  void initState() {
    super.initState();
    // Initialize with all places
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final placeProvider = Provider.of<PlaceProvider>(context, listen: false);
      setState(() {
        _filteredPlaces = placeProvider.places;
      });
    });
  }

  void _filterPlaces(String query) {
    final placeProvider = Provider.of<PlaceProvider>(context, listen: false);
    final places = placeProvider.places;
    final locale = Provider.of<LocalizationProvider>(
      context,
      listen: false,
    ).locale.languageCode;
    // Simple client-side filter first (fast). If no results, call backend search.
    setState(() {
      if (query.isEmpty) {
        _filteredPlaces = places;
        return;
      }

      _filteredPlaces = places.where((place) {
        final name = place.localizedName(locale).toLowerCase();
        final loc = place.location.toLowerCase();
        final q = query.toLowerCase();
        return name.contains(q) || loc.contains(q);
      }).toList();
    });

    // If client-side did not find matches, try server-side search
    if (_filteredPlaces.isEmpty && query.trim().length >= 2) {
      _performServerSearch(query.trim());
    }
  }

  Future<void> _performServerSearch(String query) async {
    try {
      final placeService = Provider.of<PlaceService>(context, listen: false);
      final dtos = await placeService.getPlaces(search: query, limit: 50);
      final results = dtos.map((d) => d.toPlace()).toList();
      if (mounted) {
        setState(() {
          _filteredPlaces = results;
        });
      }
    } catch (e) {
      debugPrint('Server search failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocalizationProvider>(
      context,
    ).locale.languageCode;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        title: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Search places...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).dividerColor,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context).dividerColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _filterPlaces('');
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
      body: _filteredPlaces.isEmpty && _searchController.text.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).dividerColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không tìm thấy địa điểm',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thử tìm kiếm với từ khóa khác',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredPlaces.length,
              itemBuilder: (context, index) {
                final place = _filteredPlaces[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: Theme.of(
                    context,
                  ).cardColor, // Ensure card color matches theme
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        place.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, size: 40),
                      ),
                    ),
                    title: Text(
                      place.localizedName(locale),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    isThreeLine: true,
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          place.location,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              place.rating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${place.commentCount})',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaceDetailScreen(place: place),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
