import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KODIR GPS',
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
  final Set<Marker> _markers = {};
  static const kGoogleApiKey = "AIzaSyAtINayJ-zJovfZkv6jPjEu7iECO5pOCzU";
  final Mode _mode = Mode.overlay;
  List<LatLng> _locations = []; // Daftar lokasi yang dipilih oleh pengguna

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation(); // Panggil fungsi untuk mendapatkan lokasi saat ini
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('${position.latitude}_${position.longitude}'),
          position: position,
          infoWindow: const InfoWindow(
            title: 'Lokasi Terpilih',
            snippet: 'Ini adalah lokasi yang Anda pilih',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _locations.add(position); // Tambah lokasi ke dalam daftar
    });
  }

  void _onMapTapped(LatLng position) async {
    _addMarker(position);

    // Mendapatkan alamat dari koordinat yang ditap
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      print('Alamat: ${place.street}, ${place.locality}, ${place.country}');
    }

    // Animasikan kamera peta ke lokasi yang ditap
    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: position,
        zoom: 14.0,
      ),
    ));
  }

  void _startRoute() {
    if (_locations.isNotEmpty) {
      // Menghapus semua marker kecuali yang terakhir
      List<Marker> newMarkers = [_markers.last];
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });

      // Animasi kamera peta ke lokasi terakhir dalam _locations
      LatLng lastLocation = _locations.last;
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: lastLocation,
          zoom: 14.0,
        ),
      ));

      // Tampilkan snackbar notifikasi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.blue,
          content: const Text('Lokasi telah diperbarui.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handlePressButton() async {
    try {
      Prediction? p = await PlacesAutocomplete.show(
        context: context,
        apiKey: kGoogleApiKey,
        mode: _mode,
        language: "en",
        components: [Component(Component.country, "id")],
      );

      if (p != null) {
        await displayPrediction(p, mapController);
      }
    } catch (e) {
      print("Error during search: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> displayPrediction(
      Prediction p, GoogleMapController controller) async {
    try {
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

      // Contoh penggunaan geocoding untuk mendapatkan alamat dari koordinat
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        print('Alamat: ${place.street}, ${place.locality}, ${place.country}');
      }
    } catch (e) {
      print("Error displaying prediction: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _addMarker(
          currentLatLng); // Gunakan hasil dari Geolocator untuk menambah marker
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLatLng,
          zoom: 14.0,
        ),
      ));
    } catch (e) {
      print("Error getting current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KODIR GPS'),
        backgroundColor: Colors.grey,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handlePressButton,
          ),
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _getCurrentLocation,
            color: Colors.blue,
            iconSize: 30,
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(0,
              0), // Target awal tidak penting karena akan diganti oleh lokasi aktual
          zoom: 11.0,
        ),
        markers: _markers.isNotEmpty ? Set<Marker>.of(_markers) : Set<Marker>(),
        onTap: _onMapTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startRoute, // Menghubungkan dengan fungsi startRoute
        child: const Icon(Icons.navigation),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // Menempatkan di kiri bawah
    );
  }
}
