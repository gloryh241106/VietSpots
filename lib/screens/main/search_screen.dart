import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/place_provider.dart';
import 'package:vietspots/screens/detail/place_detail_screen.dart';

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

    setState(() {
      if (query.isEmpty) {
        _filteredPlaces = places;
      } else {
        _filteredPlaces = places.where((place) {
          return place.name.toLowerCase().contains(query.toLowerCase()) ||
              place.location.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search places...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _filterPlaces,
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredPlaces.length,
        itemBuilder: (context, index) {
          final place = _filteredPlaces[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                place.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported),
              ),
            ),
            title: Text(place.name),
            subtitle: Text(place.location),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlaceDetailScreen(place: place),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
