import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Check and request location permissions
  static Future<bool> checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  // Get current location
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Check permissions first
      bool permissionGranted = await checkLocationPermission();
      
      if (!permissionGranted) {
        throw Exception('Location permissions not granted');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );

      // Take the first placemark
      Placemark place = placemarks[0];

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'street': place.street ?? '',
        'subLocality': place.subLocality ?? '',
        'locality': place.locality ?? '',
        'administrativeArea': place.administrativeArea ?? '',
        'postalCode': place.postalCode ?? '',
        'country': place.country ?? '',
        'fullAddress': 
          '${place.street}, ${place.subLocality}, '
          '${place.locality}, ${place.administrativeArea} '
          '${place.postalCode}'
      };
    } catch (e) {
      print('Error getting location: $e');
      return {};
    }
  }

  // Calculate distance between two coordinates
  static double calculateDistance(
    double startLatitude, 
    double startLongitude, 
    double endLatitude, 
    double endLongitude
  ) {
    return Geolocator.distanceBetween(
      startLatitude, 
      startLongitude, 
      endLatitude, 
      endLongitude
    );
  }
}
