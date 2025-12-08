import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../utils/translations.dart';
import '../theme/language_controller.dart';

class DrugstoreMapScreen extends StatefulWidget {
  const DrugstoreMapScreen({super.key});

  @override
  State<DrugstoreMapScreen> createState() => _DrugstoreMapScreenState();
}

class _DrugstoreMapScreenState extends State<DrugstoreMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isLoadingPharmacies = false;
  String? _errorMessage;
  List<PharmacyLocation> _pharmacies = [];
  double _searchRadius = 2000; // Search radius in meters

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    if (_currentLocation != null) {
      await _searchNearbyPharmacies();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          // Use default location (Istanbul) if location services are disabled
          _currentLocation = LatLng(41.0082, 28.9784);
        });
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _currentLocation = LatLng(41.0082, 28.9784);
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _currentLocation = LatLng(41.0082, 28.9784);
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _currentLocation = LatLng(41.0082, 28.9784);
      });
    }
  }

  Future<void> _searchNearbyPharmacies() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoadingPharmacies = true;
    });

    try {
      final pharmacies = await _fetchPharmaciesFromOverpass(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _searchRadius,
      );

      setState(() {
        _pharmacies = pharmacies;
        _isLoadingPharmacies = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPharmacies = false;
        _errorMessage = 'Failed to load pharmacies. Please try again.';
      });
    }
  }

  Future<List<PharmacyLocation>> _fetchPharmaciesFromOverpass(
    double lat,
    double lon,
    double radius,
  ) async {
    // Overpass API query to find pharmacies near the location
    final query =
        '''
[out:json][timeout:25];
(
  node["amenity"="pharmacy"](around:$radius,$lat,$lon);
  way["amenity"="pharmacy"](around:$radius,$lat,$lon);
  relation["amenity"="pharmacy"](around:$radius,$lat,$lon);
);
out center;
''';

    final url = Uri.parse('https://overpass-api.de/api/interpreter');

    try {
      final response = await http
          .post(url, body: {'data': query})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        final pharmacies = <PharmacyLocation>[];

        for (final element in elements) {
          double? pharmacyLat;
          double? pharmacyLon;

          // Handle nodes (points)
          if (element['type'] == 'node') {
            pharmacyLat = element['lat']?.toDouble();
            pharmacyLon = element['lon']?.toDouble();
          }
          // Handle ways and relations (use center point)
          else if (element['center'] != null) {
            pharmacyLat = element['center']['lat']?.toDouble();
            pharmacyLon = element['center']['lon']?.toDouble();
          }

          if (pharmacyLat != null && pharmacyLon != null) {
            final tags = element['tags'] as Map<String, dynamic>? ?? {};

            final name =
                tags['name'] ?? tags['brand'] ?? tags['operator'] ?? 'Pharmacy';

            final openingHours = tags['opening_hours'] ?? 'Hours not available';
            final phone = tags['phone'] ?? tags['contact:phone'];
            final website = tags['website'] ?? tags['contact:website'];
            final address = _buildAddress(tags);

            // Calculate distance from current location
            final distance = _calculateDistance(
              lat,
              lon,
              pharmacyLat,
              pharmacyLon,
            );

            pharmacies.add(
              PharmacyLocation(
                id: element['id'].toString(),
                name: name,
                location: LatLng(pharmacyLat, pharmacyLon),
                openingHours: openingHours,
                phone: phone,
                website: website,
                address: address,
                distance: distance,
              ),
            );
          }
        }

        // Sort by distance
        pharmacies.sort((a, b) => a.distance.compareTo(b.distance));

        return pharmacies;
      } else {
        throw Exception('Failed to fetch pharmacies: ${response.statusCode}');
      }
    } catch (e) {
      // Return empty list on error
      debugPrint('Error fetching pharmacies: $e');
      return [];
    }
  }

  String _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];

    if (tags['addr:street'] != null) {
      String street = tags['addr:street'];
      if (tags['addr:housenumber'] != null) {
        street = '${tags['addr:housenumber']} $street';
      }
      parts.add(street);
    }

    if (tags['addr:city'] != null) {
      parts.add(tags['addr:city']);
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Address not available';
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  void _centerOnLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  Future<void> _refreshPharmacies() async {
    await _getCurrentLocation();
    if (_currentLocation != null) {
      await _searchNearbyPharmacies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder(
      valueListenable: LanguageController.instance,
      builder: (context, _, __) {
        return Scaffold(
          body: SafeArea(
            child: _isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                    itemCount: 1 + _pharmacies.length,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    Translations.nearbyPharmacies,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (_isLoadingPharmacies)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  IconButton(
                                    onPressed: _refreshPharmacies,
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Refresh pharmacies',
                                  ),
                                IconButton(
                                  onPressed: _centerOnLocation,
                                  icon: const Icon(Icons.my_location),
                                  tooltip: 'Center on my location',
                                ),
                                IconButton(
                                  onPressed: _showRadiusDialog,
                                  icon: const Icon(Icons.tune),
                                  tooltip: 'Search radius',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 280,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildMap(theme),
                            ),
                            const SizedBox(height: 12),
                            if (_pharmacies.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  '${_pharmacies.length} pharmacies found within ${_formatDistance(_searchRadius)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (_pharmacies.isEmpty && !_isLoadingPharmacies)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.local_pharmacy_outlined,
                                        size: 48,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No pharmacies found nearby',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _searchRadius = 5000;
                                          });
                                          _searchNearbyPharmacies();
                                        },
                                        child: const Text(
                                          'Expand search radius',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      }

                      final pharmacy = _pharmacies[index - 1];
                      return _buildPharmacyCard(pharmacy, theme);
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPharmacyCard(PharmacyLocation pharmacy, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: () => _showPharmacyDetails(pharmacy),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_pharmacy,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pharmacy.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(pharmacy.distance),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            pharmacy.address,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
              IconButton(
                onPressed: () {
                  _mapController.move(pharmacy.location, 17.0);
                },
                icon: Icon(Icons.near_me, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    if (_errorMessage != null && _pharmacies.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _refreshPharmacies,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final center = _currentLocation ?? LatLng(41.0082, 28.9784);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14.0,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.dosemite.app',
              maxZoom: 19,
            ),
            // Circle showing search radius
            CircleLayer(
              circles: [
                CircleMarker(
                  point: center,
                  radius: _searchRadius,
                  useRadiusInMeter: true,
                  color: Colors.blue.withOpacity(0.1),
                  borderColor: Colors.blue.withOpacity(0.3),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Current location marker
                if (_currentLocation != null)
                  Marker(
                    point: _currentLocation!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                // Pharmacy markers
                ..._pharmacies.map(
                  (pharmacy) => Marker(
                    point: pharmacy.location,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showPharmacyDetails(pharmacy),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.local_pharmacy,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Loading overlay
        if (_isLoadingPharmacies)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempRadius = _searchRadius;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Search Radius'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Find pharmacies within:'),
                  const SizedBox(height: 16),
                  Text(
                    _formatDistance(tempRadius),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Slider(
                    value: tempRadius,
                    min: 500,
                    max: 10000,
                    divisions: 19,
                    label: _formatDistance(tempRadius),
                    onChanged: (value) {
                      setDialogState(() {
                        tempRadius = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _searchRadius = tempRadius;
                    });
                    _searchNearbyPharmacies();
                  },
                  child: const Text('Search'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPharmacyDetails(PharmacyLocation pharmacy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.local_pharmacy,
                      color: Colors.red.shade600,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pharmacy.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDistance(pharmacy.distance),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: pharmacy.address,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.access_time,
                label: 'Hours',
                value: pharmacy.openingHours,
                theme: theme,
              ),
              if (pharmacy.phone != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: pharmacy.phone!,
                  theme: theme,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mapController.move(pharmacy.location, 17.0);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('View on Map'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (pharmacy.phone != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          // In a real app, this would open the phone app
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text('Call'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class PharmacyLocation {
  final String id;
  final String name;
  final LatLng location;
  final String openingHours;
  final String? phone;
  final String? website;
  final String address;
  final double distance;

  PharmacyLocation({
    required this.id,
    required this.name,
    required this.location,
    required this.openingHours,
    this.phone,
    this.website,
    required this.address,
    required this.distance,
  });
}
