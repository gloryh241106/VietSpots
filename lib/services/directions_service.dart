import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DirectionStep {
  final String instruction;
  final double distance; // meters
  final double duration; // seconds

  final LatLng? endLocation;

  DirectionStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.endLocation,
  });

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'distance': distance,
    'duration': duration,
    'endLocation': endLocation == null
        ? null
        : [endLocation!.latitude, endLocation!.longitude],
  };

  static DirectionStep fromJson(Map<String, dynamic> json) {
    final el = json['endLocation'];
    LatLng? end;
    if (el is List && el.length >= 2) {
      end = LatLng((el[0] as num).toDouble(), (el[1] as num).toDouble());
    }
    return DirectionStep(
      instruction: json['instruction'] ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      endLocation: end,
    );
  }
}

class DirectionResult {
  final List<LatLng> polyline;
  final List<DirectionStep> steps;

  DirectionResult({required this.polyline, required this.steps});

  Map<String, dynamic> toJson() => {
    'polyline': polyline.map((p) => [p.latitude, p.longitude]).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  static DirectionResult fromJson(Map<String, dynamic> json) {
    final poly = <LatLng>[];
    final pList = json['polyline'] as List<dynamic>? ?? [];
    for (final item in pList) {
      if (item is List && item.length >= 2) {
        poly.add(
          LatLng((item[0] as num).toDouble(), (item[1] as num).toDouble()),
        );
      }
    }
    final steps = <DirectionStep>[];
    final sList = json['steps'] as List<dynamic>? ?? [];
    for (final s in sList) {
      if (s is Map<String, dynamic>) steps.add(DirectionStep.fromJson(s));
    }
    return DirectionResult(polyline: poly, steps: steps);
  }
}

class DirectionsService {
  /// Use OSRM public demo server to fetch driving route between two points.
  /// lon,lat order for OSRM path.
  static const _base = 'https://router.project-osrm.org';

  // Simple in-memory cache keyed by "originLng,originLat|destLng,destLat"
  final Map<String, DirectionResult> _cache = {};
  bool _cacheLoaded = false;

  Future<DirectionResult?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // ensure cache loaded
    if (!_cacheLoaded) await _loadCacheFromPrefs();
    final key =
        '${originLng.toString()},${originLat.toString()}|${destLng.toString()},${destLat.toString()}';
    // return cached if exists
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final coords =
          '${originLng.toString()},${originLat.toString()};${destLng.toString()},${destLat.toString()}';
      final uri = Uri.parse(
        '$_base/route/v1/driving/$coords?overview=full&geometries=geojson&steps=true',
      );
      var res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        // On web, OSRM public server may be blocked by CORS. Try a public CORS proxy as a fallback.
        if (kIsWeb) {
            try {
            final proxy = Uri.parse(
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(uri.toString())}',
            );
            final proxyRes = await http
                .get(proxy)
                .timeout(const Duration(seconds: 10));
            if (proxyRes.statusCode == 200) {
              res = proxyRes;
            } else {
              return null;
            }
          } catch (_) {
            return null;
          }
        } else {
          return null;
        }
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final routes = (body['routes'] as List<dynamic>?) ?? [];
      if (routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;

      // Parse geojson geometry
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordsList = (geometry?['coordinates'] as List<dynamic>?) ?? [];
      final polyline = <LatLng>[];
      for (final item in coordsList) {
        if (item is List && item.length >= 2) {
          final lon = (item[0] as num).toDouble();
          final lat = (item[1] as num).toDouble();
          polyline.add(LatLng(lat, lon));
        }
      }

      // Parse steps
      final stepsOut = <DirectionStep>[];
      final legs = (route['legs'] as List<dynamic>?) ?? [];
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final steps = (legMap['steps'] as List<dynamic>?) ?? [];
        for (final s in steps) {
          final mmap = s as Map<String, dynamic>;
          final maneuver = mmap['maneuver'] as Map<String, dynamic>?;
          final type = maneuver?['type'] ?? '';
          final modifier = maneuver?['modifier'] ?? '';
          final name = mmap['name'] ?? '';
          final distance = (mmap['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (mmap['duration'] as num?)?.toDouble() ?? 0.0;
          // Try to extract step end location from step geometry when available
          LatLng? stepEnd;
          final stepGeom = mmap['geometry'];
          if (stepGeom is Map && stepGeom['coordinates'] is List) {
            final coords = stepGeom['coordinates'] as List<dynamic>;
            if (coords.isNotEmpty) {
              final last = coords.last as List<dynamic>;
              final lon = (last[0] as num).toDouble();
              final lat = (last[1] as num).toDouble();
              stepEnd = LatLng(lat, lon);
            }
          } else if (stepGeom is List && stepGeom.isNotEmpty) {
            final last = stepGeom.last as List<dynamic>;
            final lon = (last[0] as num).toDouble();
            final lat = (last[1] as num).toDouble();
            stepEnd = LatLng(lat, lon);
          }

          String instruction;
          final typeStr = type.toString();
          final modifierStr = modifier.toString();
          if ((name as String?)?.isNotEmpty == true) {
            instruction =
                '$typeStr${modifierStr != '' ? ' $modifierStr' : ''} onto $name';
          } else {
            instruction = '$typeStr${modifierStr != '' ? ' $modifierStr' : ''}';
          }

          stepsOut.add(
            DirectionStep(
              instruction: instruction,
              distance: distance,
              duration: duration,
              endLocation: stepEnd,
            ),
          );
        }
      }

      final result = DirectionResult(polyline: polyline, steps: stepsOut);
      _cache[key] = result;
      await _saveCacheToPrefs();
      return result;
    } catch (e) {
      return null;
    }
  }

  DirectionResult? getCached(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final key =
        '${originLng.toString()},${originLat.toString()}|${destLng.toString()},${destLat.toString()}';
    return _cache[key];
  }

  Future<void> _loadCacheFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('directions_cache');
      if (raw == null) {
        _cacheLoaded = true;
        return;
      }
      final map = json.decode(raw) as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          try {
            _cache[k] = DirectionResult.fromJson(v);
          } catch (_) {}
        }
      });
    } catch (_) {}
    _cacheLoaded = true;
  }

  Future<void> _saveCacheToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      _cache.forEach((k, v) => map[k] = v.toJson());
      await prefs.setString('directions_cache', json.encode(map));
    } catch (_) {}
  }
}
