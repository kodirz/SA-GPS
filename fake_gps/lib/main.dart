import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity/connectivity.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SA GPS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapScreen(),
    );
  }
}

class FavoriteLocation {
  final String name;
  final LatLng location;

  FavoriteLocation({required this.name, required this.location});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': location.latitude,
      'longitude': location.longitude,
    };
  }

  static FavoriteLocation fromJson(Map<String, dynamic> json) {
    return FavoriteLocation(
      name: json['name'],
      location: LatLng(json['latitude'], json['longitude']),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};
  LatLng? _selectedLocation; // Lokasi yang dipilih oleh pengguna
  bool _isFetchingLocation = false;
  final List<FavoriteLocation> _favoriteLocations = []; // Daftar lokasi favorit
  late SharedPreferences _prefs; // SharedPreferences instance

  @override
  void initState() {
    super.initState();
    _initPrefs(); // Initialize SharedPreferences
  }

  // Function to initialize SharedPreferences
  void _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavoriteLocations(); // Load favorite locations from SharedPreferences
  }

  // Function to save favorite locations to SharedPreferences
  Future<void> _saveFavoriteLocations() async {
    List<String> favoriteLocationsJson = _favoriteLocations
        .map((location) => jsonEncode(location.toJson()))
        .toList();
    await _prefs.setStringList('favoriteLocations', favoriteLocationsJson);
  }

  // Function to load favorite locations from SharedPreferences
  void _loadFavoriteLocations() {
    List<String>? favoriteLocationsJson =
        _prefs.getStringList('favoriteLocations');
    if (favoriteLocationsJson != null) {
      _favoriteLocations.clear();
      for (String jsonString in favoriteLocationsJson) {
        _favoriteLocations
            .add(FavoriteLocation.fromJson(jsonDecode(jsonString)));
      }
      setState(() {}); // Update the view after loading favorite locations
    }
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation(); // Call function to get current location
  }

  void _addMarker(LatLng position, {bool isFavorite = false}) {
    setState(() {
      _markers.clear(); // Clear all markers before adding new ones
      _markers.add(
        Marker(
          markerId: MarkerId(isFavorite
              ? 'favorite_location_${position.toString()}'
              : 'selected_location'),
          position: position,
          infoWindow: InfoWindow(
            title: isFavorite ? 'Lokasi Favorit' : 'Lokasi Terpilih',
            snippet: isFavorite
                ? 'Ini adalah lokasi favorit Anda'
                : 'Ini adalah lokasi yang Anda pilih',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              isFavorite ? BitmapDescriptor.hueRed : BitmapDescriptor.hueBlue),
        ),
      );
      _selectedLocation = position; // Save the selected location
    });
  }

  void _onMapTapped(LatLng position) async {
    _addMarker(position);

    // Get address from tapped coordinates
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      print('Alamat: ${place.street}, ${place.locality}, ${place.country}');
    }

    // Animate map camera to tapped location
    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: position,
        zoom: 14.0,
      ),
    ));
  }

  void _startRoute() {
    if (_selectedLocation != null) {
      // Animate map camera to selected location
      LatLng selectedLocation = _selectedLocation!;
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: selectedLocation,
          zoom: 14.0,
        ),
      ));

      _showSnackBar('Navigasi dimulai ke lokasi terpilih.');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isFetchingLocation = true;
      });

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Tidak ada koneksi internet');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _addMarker(currentLatLng); // Use Geolocator result to add marker
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLatLng,
          zoom: 14.0,
        ),
      ));

      setState(() {
        _isFetchingLocation = false;
      });
    } catch (e) {
      print("Error getting current location: $e");
      _showSnackBar('Error getting current location: $e');
      setState(() {
        _isFetchingLocation = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _fetchCurrentLocationAndSetMarker() async {
    try {
      setState(() {
        _isFetchingLocation = true;
      });

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Tidak ada koneksi internet');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      _addMarker(currentLatLng);

      setState(() {
        _isFetchingLocation = false;
      });

      _showSnackBar('Lokasi telah diperbarui.');

      // After updating marker, set map camera to follow the new marker
      mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLatLng,
          zoom: 14.0,
        ),
      ));
    } catch (e) {
      setState(() {
        _isFetchingLocation = false;
      });
      _showSnackBar('Gagal mendapatkan lokasi saat ini: $e');
    }
  }

  void _handleGPSFixedPressed() {
    _showSnackBar('Mengambil lokasi saat ini...');
    _fetchCurrentLocationAndSetMarker();
  }

  void _addFavoriteLocation() {
    if (_selectedLocation != null) {
      TextEditingController nameController = TextEditingController();
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Tambahkan Lokasi Favorit'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Nama Lokasi',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isEmpty) {
                    _showSnackBar('Masukkan nama lokasi terlebih dahulu.');
                  } else {
                    setState(() {
                      _favoriteLocations.add(FavoriteLocation(
                        name: nameController.text,
                        location: _selectedLocation!,
                      ));
                      _addMarker(_selectedLocation!,
                          isFavorite: true); // Add favorite marker
                      _saveFavoriteLocations(); // Save to SharedPreferences
                    });
                    Navigator.of(context).pop();
                    _showSnackBar('Lokasi favorit ditambahkan.');
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    } else {
      _showSnackBar('Tidak ada lokasi yang dipilih.');
    }
  }

  void _navigateToFavorite(FavoriteLocation favorite) {
    setState(() {
      _markers.clear(); // Clear all markers before adding new ones
      _markers.add(
        Marker(
          markerId:
              MarkerId('favorite_location_${favorite.location.toString()}'),
          position: favorite.location,
          infoWindow: InfoWindow(
            title: 'Lokasi Favorit',
            snippet: 'Ini adalah lokasi favorit Anda',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
    mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: favorite.location,
        zoom: 14.0,
      ),
    ));
  }

  void _showFavoritesMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ListView.builder(
              itemCount: _favoriteLocations.length,
              itemBuilder: (context, index) {
                final favorite = _favoriteLocations[index];
                return ListTile(
                  title: Text(favorite.name),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToFavorite(favorite);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Konfirmasi'),
                            content: const Text(
                                'Apakah Anda yakin ingin menghapus lokasi ini?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Tidak'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    // Remove the favorite location and corresponding marker
                                    _favoriteLocations.removeAt(index);
                                    _markers.removeWhere((marker) =>
                                        marker.markerId.value ==
                                        'favorite_location_${favorite.location.toString()}');
                                    _saveFavoriteLocations(); // Save to SharedPreferences

                                    // Add back the blue marker for current location
                                    if (_selectedLocation != null) {
                                      _addMarker(_selectedLocation!);
                                    }
                                  });
                                  Navigator.of(context)
                                      .pop(); // Close confirmation dialog
                                  _showSnackBar('Lokasi favorit dihapus.');
                                },
                                child: const Text('Iya'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SA GPS'),
          backgroundColor: const Color.fromARGB(255, 103, 153, 180),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.favorite,
                color: Colors.red, // Change icon color to red
              ),
              onPressed: _showFavoritesMenu,
            ),
          ],
        ),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(
            target: LatLng(0,
                0), // Initial target doesn't matter as it will be replaced by actual location
            zoom: 11.0,
          ),
          markers:
              _markers.isNotEmpty ? Set<Marker>.of(_markers) : Set<Marker>(),
          onTap: _onMapTapped,
        ),
        floatingActionButton: _isFetchingLocation
            ? FloatingActionButton(
                onPressed: null,
                backgroundColor: Colors.blue,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: _handleGPSFixedPressed,
                    child: const Icon(Icons.gps_fixed),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    onPressed: _startRoute,
                    child: const Icon(Icons.navigation),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    onPressed: _addFavoriteLocation,
                    child: const Icon(Icons.add),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.startFloat, // Position at bottom left
      ),
    );
  }

  Future<bool> _onBackPressed() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Konfirmasi'),
            content: Text('Apakah Anda ingin meninggalkan aplikasi ini?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Tidak'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Iya'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
