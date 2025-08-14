import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/aprs_packet.dart';
import '../../tnc/benshi/radio_controller.dart';
import '../../tnc/mobilinkd/mobilinkd_controller.dart';

class MapScreen extends StatefulWidget {
  final ChangeNotifier controller;

  const MapScreen({super.key, required this.controller});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  ValueNotifier<List<AprsPacket>>? _packetNotifier;

  @override
  void initState() {
    super.initState();
    _initializeLocation();

    // Set the correct packet notifier based on the controller type
    if (widget.controller is RadioController) {
      _packetNotifier = (widget.controller as RadioController).aprsPackets;
    } else if (widget.controller is MobilinkdController) {
      _packetNotifier = (widget.controller as MobilinkdController).aprsPackets;
    }
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Location permissions are permanently denied.');
      return;
    }

    // Get initial position
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      _mapController.move(LatLng(position.latitude, position.longitude), 13.0);
    } catch (e) {
      _showError('Could not get initial position.');
    }


    // Listen for position changes
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APRS Map'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ValueListenableBuilder<List<AprsPacket>>(
        valueListenable: _packetNotifier ?? ValueNotifier([]),
        builder: (context, packets, child) {
          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(41.76, -80.79), // Default to Jefferson, OH
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.rose.aprsdart',
              ),
              MarkerLayer(
                markers: _buildMarkers(packets),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  List<Marker> _buildMarkers(List<AprsPacket> packets) {
    final List<Marker> markers = [];

    // Add user's location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40.0),
        ),
      );
    }

    // Add APRS packet markers
    for (final packet in packets) {
      if (packet.latitude != null && packet.longitude != null) {
        markers.add(
          Marker(
            width: 120.0,
            height: 90.0,
            point: LatLng(packet.latitude!, packet.longitude!),
            child: GestureDetector(
              onTap: () => _showPacketDetails(packet),
              child: Column(
                children: [
                  const Icon(Icons.cell_tower, color: Colors.red, size: 30.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      packet.source,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  void _showPacketDetails(AprsPacket packet) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.cell_tower),
                title: Text(packet.source, style: Theme.of(context).textTheme.headlineSmall),
                subtitle: Text('via ${packet.path.join(', ')}'),
              ),
              const Divider(),
              ListTile(
                title: const Text('Information'),
                subtitle: Text(packet.info),
              ),
               ListTile(
                title: const Text('Timestamp'),
                subtitle: Text(packet.timestamp.toLocal().toString()),
              ),
            ],
          ),
        );
      },
    );
  }
}