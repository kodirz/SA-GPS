import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
// import 'package:geocoding/geocoding.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake GPS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final LatLng _initialCenter =
      const LatLng(-7.795580, 110.369490); // Koordinat Yogyakarta
  LatLng _currentCenter = const LatLng(-7.795580, 110.369490);
  final Set<Marker> _markers = {};
  static const kGoogleApiKey = "YOUR_API_KEY";
  final Mode _mode = Mode.overlay;

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _addMarker(_initialCenter);
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear(); // Hapus marker sebelumnya jika ada
      _markers.add(
        Marker(
          markerId: const MarkerId('center_marker'),
          position: position,
          infoWindow: const InfoWindow(
            title: 'Yogyakarta',
            snippet: 'Ini adalah lokasi di Yogyakarta',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _currentCenter = position;
    });
  }

  void _onMapTapped(LatLng position) {
    _addMarker(position);
  }

  Future<void> _handlePressButton() async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: _mode,
      language: "en",
      components: [Component(Component.country, "id")],
    );

    displayPrediction(p!, mapController);
  }

  Future<void> displayPrediction(
      Prediction p, GoogleMapController controller) async {
    if (p != null) {
      GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId(p.placeId!);
      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;

      _addMarker(LatLng(lat, lng));
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: 14.0,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake GPS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handlePressButton,
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialCenter,
          zoom: 11.0,
        ),
        markers: _markers,
        onTap: _onMapTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          mapController.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentCenter,
              zoom: 14.0,
            ),
          ));
        },
        child: const Icon(Icons.location_searching),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // Menempatkan di kiri bawah
    );
  }
}
