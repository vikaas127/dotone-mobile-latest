import 'dart:async';
import 'dart:convert';
import 'package:dotone/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart' as latLng;

class MapTrackingPage extends StatefulWidget {
  final String date;
  final double lat;
  final double lng;

  const MapTrackingPage({
    Key? key,
    required this.date,
    required this.lat,
    required this.lng,
  }) : super(key: key);

  @override
  State<MapTrackingPage> createState() => _MapTrackingPageState();
}

class _MapTrackingPageState extends State<MapTrackingPage> {
  final ApiService api = ApiService();
  final MapController _mapController = MapController();

  List<latLng.LatLng> routePoints = [];
  List<Marker> markers = [];
  List<Map<String, dynamic>> activityDetails = [];
  List<Map<String, dynamic>> stopPoints = [];

  bool loading = true;
  double totalDistance = 0.0;
  String duration = "";

  @override
  void initState() {
    super.initState();
    loadRouteFromAPI();
  }

  /// ✅ Fetch route and activity data from backend
  Future<void> loadRouteFromAPI() async {
    print(widget.date);
    final res = await api.getDirectionRoute(date: widget.date);

    if (res['success'] == true) {
      final data = res['data'];
      final encodedPolyline = data['polyline'];
      final decodedPoints = PolylinePoints().decodePolyline(encodedPolyline);

      routePoints = decodedPoints
          .map((p) => latLng.LatLng(p.latitude, p.longitude))
          .toList();

      totalDistance =
          double.tryParse(data['total_distance'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      duration = data['duration'] ?? "";

      // ✅ Add start and end markers
      final start = data['start'];
      final end = data['end'];

      markers = [
        Marker(
          point: latLng.LatLng(start['lat'], start['lng']),
          width: 40,
          height: 40,
          child: const Icon(Icons.play_arrow, color: Colors.green, size: 35),
        ),
        Marker(
          point: latLng.LatLng(end['lat'], end['lng']),
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: Colors.red, size: 35),
        ),
      ];

      // ✅ Add small points for route path
      final path = data['path'] as List;
      for (final p in path) {
        markers.add(
          Marker(
            point: latLng.LatLng(p['lat'], p['lng']),
            width: 10,
            height: 10,
            child: const Icon(Icons.circle, color: Colors.amber, size: 8),
          ),
        );
      }

      // ✅ Get activity list & stop points (optional from backend)
      activityDetails = List<Map<String, dynamic>>.from(data['activities'] ?? []);
      stopPoints = List<Map<String, dynamic>>.from(data['stops'] ?? []);

      // ✅ Mark stop points distinctly
      for (final stop in stopPoints) {
        markers.add(
          Marker(
            point: latLng.LatLng(stop['lat'], stop['lng']),
            width: 40,
            height: 40,
            child: const Icon(Icons.pause_circle_filled,
                color: Colors.blue, size: 32),
          ),
        );
      }

      setState(() => loading = false);
    } else {
      debugPrint('⚠️ Error: ${res['message']}');
      setState(() => loading = false);
    }
  }

  // Helper for distance parsing
  double _parseDistance(String? distanceStr) {
    if (distanceStr == null) return 0.0;
    return double.tryParse(distanceStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text('Tracking - ${widget.date}'),
        backgroundColor: Colors.green,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // ✅ Map View
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: routePoints.isNotEmpty
                    ? routePoints.first
                    : latLng.LatLng(widget.lat, widget.lng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.techdotbit.dotone',
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: const Color(0xff0B61D8),
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // ✅ Trip Summary Info
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${(totalDistance).toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Duration: $duration',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // ✅ Activity List View
          // ✅ Activity Timeline List
        /*  Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xffF9F9F9),
              child: activityDetails.isEmpty
                  ? const Center(child: Text('No activity records found'))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: activityDetails.length,
                itemBuilder: (context, index) {
                  final item = activityDetails[index];
                  final type = item['type'] ?? 'movement';
                  final address = item['address'] ?? 'Unknown location';
                  final time = item['time'] ?? '-';
                  final distance = item['distance'] ?? '0 m';
                  final stopDuration = item['stop_duration'] ?? '';

                  IconData icon;
                  Color color;

                  if (type == 'checkin') {
                    icon = Icons.login;
                    color = Colors.green;
                  } else if (type == 'checkout') {
                    icon = Icons.logout;
                    color = Colors.red;
                  } else if (type == 'stop') {
                    icon = Icons.pause_circle_filled;
                    color = Colors.blue;
                  } else {
                    icon = Icons.directions_walk;
                    color = Colors.orange;
                  }

                  // 👇 Timeline item layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left timeline column (icon + line)
                      Column(
                        children: [
                          // Timeline circle/icon
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Icon(icon, color: color, size: 14),
                          ),

                          // Connector line (except last item)
                          if (index != activityDetails.length - 1)
                            Container(
                              width: 2,
                              height: 50,
                              color: Colors.grey.shade300,
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),

                      // Right details
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(time, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                              if (stopDuration.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Stop Duration: $stopDuration',
                                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                ),
                              if (distance != '0 m')
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('Distance: $distance',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  );
                },
              ),
            ),
          ),*/

        ],
      ),
    );
  }
}
