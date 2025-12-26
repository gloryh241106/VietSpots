import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/utils/typography.dart';
import 'package:provider/provider.dart';

class DirectionsMapScreen extends StatefulWidget {
  const DirectionsMapScreen({super.key, required this.place});

  final Place place;

  @override
  State<DirectionsMapScreen> createState() => _DirectionsMapScreenState();
}

class _DirectionsMapScreenState extends State<DirectionsMapScreen> {
  Position? _current;

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);
  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      if (mounted) setState(() => _current = pos);
    } catch (_) {
      // keep null and fallback to demo
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final curLat = _current?.latitude ?? 10.7769;
    final curLng = _current?.longitude ?? 106.7006;
    final distanceKm = _haversineDistance(
      curLat,
      curLng,
      place.latitude,
      place.longitude,
    );
    final estimatedMinutes = (distanceKm / 40) * 60; // assume 40 km/h average
    final points = [
      LatLng(curLat, curLng),
      LatLng(place.latitude, place.longitude),
    ];

    final loc = Provider.of<LocalizationProvider>(context);
    final locale = loc.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(place.localizedName(locale))),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(
                  (curLat + place.latitude) / 2,
                  (curLng + place.longitude) / 2,
                ),
                zoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.trackasia.com/styles/v1/trackasia/streets-v11/tiles/{z}/{x}/{y}?access_token=${dotenv.env['TRACKASIA_API_KEY'] ?? ''}',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points[0],
                      width: 40,
                      height: 40,
                      builder: (ctx) => const Icon(
                        Icons.person_pin_circle,
                        color: Colors.green,
                        size: 36,
                      ),
                    ),
                    Marker(
                      point: points[1],
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
          SafeArea(
            top: false,
            minimum: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loc.translate('distance')}: ${distanceKm.toStringAsFixed(1)} km',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${loc.translate('estimated_time')}: ${estimatedMinutes.round()} min',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc.translate('start_navigation_placeholder'),
                          ),
                        ),
                      );
                    },
                    child: Text(loc.translate('start')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
