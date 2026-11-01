import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/supabase_service.dart';
import '../widgets/top_banner.dart';

class LocationPickerResult {
  final String address;
  final double latitude;
  final double longitude;

  LocationPickerResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  
  LatLng _stationCenter = const LatLng(14.2290, 121.3280); // Victoria, Laguna Station Default
  double _maxCoverageRadiusMeters = 500.0; // 0.5 KM Radius Default
  double _coverageRadiusKm = 0.5;
  String _stationName = 'Aqua Pure Water Station';

  late LatLng _currentCenter;
  bool _isLocating = true;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = _stationCenter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStationGeofenceAndUserLocation();
    });
  }

  Future<void> _loadStationGeofenceAndUserLocation() async {
    try {
      final shopData = await SupabaseService.fetchShopProfile();
      final lat = (shopData['latitude'] as num?)?.toDouble() ?? 14.2290;
      final lng = (shopData['longitude'] as num?)?.toDouble() ?? 121.3280;
      final radiusKm = (shopData['coverage_radius_km'] as num?)?.toDouble() ?? 0.5;
      final name = (shopData['full_name'] as String?) ?? 'Aqua Pure Water Station';

      if (mounted) {
        setState(() {
          _stationCenter = LatLng(lat, lng);
          _coverageRadiusKm = radiusKm;
          _maxCoverageRadiusMeters = radiusKm * 1000.0;
          _stationName = name;
          _currentCenter = _stationCenter;
        });
      }
    } catch (_) {}

    await _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text('Please enable GPS / location services on your device to automatically detect your delivery address.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openLocationSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('📍 GPS Location Permission'),
              content: const Text('AquaSync requires location access to find your exact delivery address and verify station delivery proximity.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Not Now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionMessage('Location permission denied. Adjust map pin manually within the boundary.');
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Denied'),
              content: const Text('Location permission is permanently denied. Please enable it in your phone settings to use GPS auto-location.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('Open App Settings'),
                ),
              ],
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentCenter = newCenter;
          _isLocating = false;
        });
        _mapController.move(newCenter, 16.5);
      }
    } catch (_) {
      if (mounted) {
        _showPermissionMessage('Could not retrieve device location. Adjust map pin manually within boundary.');
        setState(() => _isLocating = false);
      }
    }
  }

  void _showPermissionMessage(String message) {
    TopBanner.show(context, message, isError: false);
  }

  Future<void> _confirmLocation() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    final selectedCenter = _mapController.camera.center;

    // ADMIN DYNAMIC GEOFENCING VALIDATION CHECK
    final distanceMeters = Geolocator.distanceBetween(
      _stationCenter.latitude,
      _stationCenter.longitude,
      selectedCenter.latitude,
      selectedCenter.longitude,
    );

    // Strict geofence validation check: location must be strictly within the station circle radius
    if (distanceMeters > _maxCoverageRadiusMeters) {
      final distanceKm = (distanceMeters / 1000.0).toStringAsFixed(2);
      if (mounted) {
        setState(() => _isConfirming = false);
        TopBanner.show(
          context,
          'Selected location is $distanceKm km away from station. Admin allowed proximity limit is ${_coverageRadiusKm.toStringAsFixed(1)} km.',
          isError: true,
        );
      }
      return;
    }

    String formattedAddress = '${selectedCenter.latitude.toStringAsFixed(5)}, ${selectedCenter.longitude.toStringAsFixed(5)}';

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        selectedCenter.latitude,
        selectedCenter.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final addressParts = [
          if (p.street != null && p.street!.isNotEmpty) p.street,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
          if (p.country != null && p.country!.isNotEmpty) p.country,
        ];

        if (addressParts.isNotEmpty) {
          formattedAddress = addressParts.join(', ');
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
        final result = LocationPickerResult(
          address: formattedAddress,
          latitude: selectedCenter.latitude,
          longitude: selectedCenter.longitude,
        );
        Navigator.of(context).pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Delivery Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7)),
            onPressed: _getUserLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap with Geofence Circle Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.5,
              maxZoom: 18.5,
              minZoom: 10.0,
              onPositionChanged: (camera, hasGesture) {
                _currentCenter = camera.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aquasync_user_app',
                maxZoom: 19,
                maxNativeZoom: 19,
              ),
              // 🔵 ADMIN GEOFENCE COVERAGE CIRCLE
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _stationCenter,
                    radius: _maxCoverageRadiusMeters,
                    useRadiusInMeter: true,
                    color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                    borderColor: const Color(0xFF0284C7),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              // 🏪 STATION CENTER MARKER
              MarkerLayer(
                markers: [
                  Marker(
                    point: _stationCenter,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.store_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
                ],
              ),
            ],
          ),

          // Top Coverage Area Info Banner
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF075985),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isLocating
                          ? 'Centering on GPS location...'
                          : '${_coverageRadiusKm.toStringAsFixed(1)}km Proximity Geofence Active ($_stationName)',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Pin Indicator (Pin tip aligned exactly at map center)
          IgnorePointer(
            child: Center(
              child: FractionalTranslation(
                translation: const Offset(0.0, -0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF075985),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Delivery Pin',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFDC2626),
                      size: 44,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Re-center FAB
          Positioned(
            right: 16,
            bottom: 216,
            child: FloatingActionButton(
              heroTag: 'gps_recenter_fab',
              onPressed: _getUserLocation,
              backgroundColor: cardBg,
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7), size: 24),
            ),
          ),

          // Bottom Confirmation Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF0284C7), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Delivery Location',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pan map to adjust pin. Must be within ${_coverageRadiusKm.toStringAsFixed(1)} km allowed proximity radius from $_stationName.',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isConfirming ? null : _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isConfirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('CONFIRM LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
