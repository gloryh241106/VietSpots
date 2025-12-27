import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/providers/localization_provider.dart';
import 'package:vietspots/utils/typography.dart';
import 'package:vietspots/utils/trackasia.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:vietspots/services/directions_service.dart';

class DirectionsMapScreen extends StatefulWidget {
  const DirectionsMapScreen({super.key, required this.place});

  final Place place;

  @override
  State<DirectionsMapScreen> createState() => _DirectionsMapScreenState();
}

class _DirectionsMapScreenState extends State<DirectionsMapScreen> {
  Position? _current;
  List<LatLng> _routePoints = [];
  List<DirectionStep> _routeSteps = [];
  int _activeStepIndex = -1;
  bool _navStarted = false;
  StreamSubscription<Position>? _positionSub;
  final ScrollController _stepsScrollController = ScrollController();

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

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (mounted) setState(() => _current = pos);
      // After obtaining current location, fetch route
      await _fetchRoute();
    } catch (_) {
      // keep null and fallback to demo
    }
  }

  Future<void> _fetchRoute() async {
    final cur = _current;
    if (cur == null) return;
    setState(() {
      _routePoints = [];
      _routeSteps = [];
    });
    final svc = DirectionsService();
    final res = await svc.getRoute(
      originLat: cur.latitude,
      originLng: cur.longitude,
      destLat: widget.place.latitude,
      destLng: widget.place.longitude,
    );
    if (res != null && res.polyline.isNotEmpty) {
      setState(() {
        _routePoints = res.polyline;
        _routeSteps = res.steps;
      });
    } else {
      // fallback: straight line
      setState(() {
        _routePoints = [
          LatLng(cur.latitude, cur.longitude),
          LatLng(widget.place.latitude, widget.place.longitude),
        ];
        _routeSteps = [];
      });
    }
  }

  void _startInAppNavigation() {
    if (_navStarted) return;
    setState(() {
      _navStarted = true;
      _activeStepIndex = _routeSteps.isNotEmpty ? 0 : -1;
    });
    _scrollToActiveStep();
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
          if (!mounted) return;
          setState(() {
            _current = pos;
          });
          _updateActiveStep(pos);
        });
  }

  void _stopInAppNavigation() {
    _positionSub?.cancel();
    _positionSub = null;
    _navStarted = false;
    setState(() {
      _activeStepIndex = -1;
    });
  }

  void _updateActiveStep(Position pos) {
    if (_routeSteps.isEmpty) return;
    double best = double.infinity;
    int bestIdx = -1;
    for (var i = 0; i < _routeSteps.length; i++) {
      final step = _routeSteps[i];
      if (step.endLocation == null) continue;
      final d = _haversineDistance(
        pos.latitude,
        pos.longitude,
        step.endLocation!.latitude,
        step.endLocation!.longitude,
      );
      if (d < best) {
        best = d;
        bestIdx = i;
      }
    }
    if (bestIdx != -1 && bestIdx != _activeStepIndex) {
      setState(() => _activeStepIndex = bestIdx);
      _scrollToActiveStep();
    }
  }

  void _scrollToActiveStep() {
    if (!_stepsScrollController.hasClients) return;
    final idx = _activeStepIndex;
    if (idx < 0) return;
    // approximate item height
    const itemHeight = 88.0;
    final offset = (idx * (itemHeight + 6)).clamp(
      0.0,
      _stepsScrollController.position.maxScrollExtent,
    );
    _stepsScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
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
    // Estimate minutes: prefer route durations from OSRM (seconds -> minutes).
    // Fallback: assume 30 km/h average driving speed when no route available.
    final estimatedMinutes = _routeSteps.isNotEmpty
        ? (_routeSteps.fold<double>(0.0, (p, s) => p + s.duration) / 60.0)
        : (distanceKm / 30.0) * 60.0; // 30 km/h average fallback

    final loc = Provider.of<LocalizationProvider>(context);
    final locale = loc.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(place.localizedName(locale))),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (curLat + place.latitude) / 2,
                  (curLng + place.longitude) / 2,
                ),
                initialZoom: 13.0,
              ),
              children: [
                // MAP: route / directions view
                // We use OpenStreetMap public tiles as the default provider.
                // If you need higher reliability or commercial use, replace
                // this template with a paid provider (Mapbox/MapTiler/etc.)
                // and set the appropriate API key in a secure place.
                TileLayer(
                  // TrackAsia tiles. Template comes from `.env` via
                  // `TRACKASIA_TILE_TEMPLATE`, or is built from
                  // `TRACKASIA_API_KEY`. See `trackAsiaTileUrl()`.
                  urlTemplate: trackAsiaTileUrl(),
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : [
                              LatLng(curLat, curLng),
                              LatLng(place.latitude, place.longitude),
                            ],
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _routePoints.isNotEmpty
                          ? _routePoints.first
                          : LatLng(curLat, curLng),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.green,
                        size: 36,
                      ),
                    ),
                    Marker(
                      point: _routePoints.isNotEmpty
                          ? _routePoints.last
                          : LatLng(place.latitude, place.longitude),
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

          if (_routeSteps.isNotEmpty)
            SizedBox(
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hướng dẫn chi tiết',
                          style: AppTypography.titleMedium,
                        ),
                        Text(
                          '${_routeSteps.length} bước',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: _routeSteps.isEmpty
                                      ? 0.0
                                      : ((_activeStepIndex + 1) /
                                                _routeSteps.length)
                                            .clamp(0.0, 1.0),
                                  minHeight: 6,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Đã: ${_completedDistance().isFinite ? _formatDistance(_completedDistance()) : '0 m'}",
                                      style: AppTypography.bodySmall,
                                    ),
                                    Text(
                                      "Còn: ${_remainingDistance().isFinite ? _formatDistance(_remainingDistance()) : '0 m'}",
                                      style: AppTypography.bodySmall,
                                    ),
                                    Text(
                                      "Thời gian còn: ${_formatDuration(_remainingDuration())}",
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              controller: _stepsScrollController,
                              itemCount: _routeSteps.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final s = _routeSteps[index];
                                final active = index == _activeStepIndex;
                                return Card(
                                  color: active
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withAlpha(20)
                                      : null,
                                  elevation: active ? 2 : 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Center(
                                            child: _maneuverIcon(s.instruction),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _capitalizeFirst(s.instruction),
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${_formatDistance(s.distance)} · ${_formatDuration(s.duration)}',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                      color: Colors.grey[600],
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${index + 1}',
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  "${loc.translate('distance')}: ${distanceKm.toStringAsFixed(1)} km",
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "${loc.translate('estimated_time')}: ${estimatedMinutes.round()} min",
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final origin = '$curLat,$curLng';
                          final destination =
                              '${place.latitude},${place.longitude}';
                          final uri = Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving',
                          );
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc.translate('could_not_open_website'),
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('Failed to launch maps: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc.translate('could_not_open_website'),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(loc.translate('start')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        if (_navStarted) {
                          _stopInAppNavigation();
                        } else {
                          _startInAppNavigation();
                        }
                      },
                      child: Text(
                        _navStarted ? 'Dừng (in-app)' : 'Bắt đầu (in-app)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _maneuverIcon(String instruction) {
    final instr = instruction.toLowerCase();
    if (instr.contains('left')) return const Icon(Icons.turn_left, size: 20);
    if (instr.contains('right')) return const Icon(Icons.turn_right, size: 20);
    if (instr.contains('continue') || instr.contains('straight')) {
      return const Icon(Icons.arrow_upward, size: 20);
    }
    if (instr.contains('merge')) return const Icon(Icons.merge_type, size: 20);
    if (instr.contains('arrive') || instr.contains('destination')) {
      return const Icon(Icons.flag, size: 20);
    }
    return const Icon(Icons.directions, size: 20);
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins min';
    final hours = (mins / 60).floor();
    final rem = mins % 60;
    return '${hours}h ${rem}m';
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  double _completedDistance() {
    if (_activeStepIndex <= 0) return 0.0;
    double sum = 0.0;
    for (var i = 0; i < _activeStepIndex && i < _routeSteps.length; i++) {
      sum += _routeSteps[i].distance;
    }
    return sum;
  }

  double _remainingDistance() {
    double total = 0.0;
    for (final s in _routeSteps) {
      total += s.distance;
    }
    return (total - _completedDistance()).clamp(0.0, double.infinity);
  }

  double _remainingDuration() {
    double total = 0.0;
    for (final s in _routeSteps) {
      total += s.duration;
    }
    double completed = 0.0;
    for (var i = 0; i < _activeStepIndex && i < _routeSteps.length; i++) {
      completed += _routeSteps[i].duration;
    }
    return (total - completed).clamp(0.0, double.infinity);
  }
}
