import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

// Enum for address types
enum AddressType {
  home,
  work,
  shipping,
  billing,
  other
}

class AddressService {
  static final _supabase = Supabase.instance.client;

  // Robust geocoding with multiple fallback strategies
  Future<Map<String, dynamic>> geocodeAddress(String address) async {
    // Predefined coordinates with detailed location information
    final predefinedLocations = {
      'bandung': {
        'lat': -6.9175, 
        'lon': 107.6191, 
        'city': 'Bandung', 
        'state': 'Jawa Barat'
      },
      'jakarta': {
        'lat': -6.2088, 
        'lon': 106.8456, 
        'city': 'Jakarta', 
        'state': 'DKI Jakarta'
      },
      'surabaya': {
        'lat': -7.2575, 
        'lon': 112.7521, 
        'city': 'Surabaya', 
        'state': 'Jawa Timur'
      },
      'medan': {
        'lat': 3.5952, 
        'lon': 98.6722, 
        'city': 'Medan', 
        'state': 'Sumatera Utara'
      },
      'semarang': {
        'lat': -6.9931, 
        'lon': 110.4208, 
        'city': 'Semarang', 
        'state': 'Jawa Tengah'
      }
    };

    // Sanitize input
    if (address.trim().isEmpty) {
      throw ArgumentError('Address cannot be empty');
    }

    // Try multiple geocoding strategies
    try {
      // Strategy 1: Direct geocoding
      List<Location> locations = [];
      try {
        locations = await locationFromAddress(address);
      } catch (directError) {
        print('Direct geocoding error: $directError');
      }

      // Strategy 2: Modified address geocoding
      if (locations.isEmpty) {
        try {
          // Try with city and country appended
          final modifiedAddress = '$address, Indonesia';
          locations = await locationFromAddress(modifiedAddress);
        } catch (modifiedError) {
          print('Modified geocoding error: $modifiedError');
        }
      }

      // Strategy 3: Predefined locations fallback
      if (locations.isEmpty) {
        final lowercaseAddress = address.toLowerCase();
        for (var entry in predefinedLocations.entries) {
          if (lowercaseAddress.contains(entry.key)) {
            return {
              'latitude': entry.value['lat'],
              'longitude': entry.value['lon'],
              'city': entry.value['city'],
              'state': entry.value['state'],
              'country': 'Indonesia',
              'original_address': address
            };
          }
        }
      }

      // Final fallback to Bandung if no location found
      if (locations.isEmpty) {
        return {
          'latitude': -6.9175,
          'longitude': 107.6191,
          'city': 'Bandung',
          'state': 'Jawa Barat',
          'country': 'Indonesia',
          'original_address': address,
          'geocode_method': 'default_fallback'
        };
      }

      // Use first location
      final location = locations.first;

      // Attempt reverse geocoding
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(
          location.latitude, 
          location.longitude
        );
      } catch (reverseError) {
        print('Reverse geocoding error: $reverseError');
      }

      // Prepare result with fallback values
      return {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'city': placemarks.isNotEmpty 
          ? (placemarks.first.locality ?? 'Bandung')
          : 'Bandung',
        'state': placemarks.isNotEmpty 
          ? (placemarks.first.administrativeArea ?? 'Jawa Barat')
          : 'Jawa Barat',
        'country': placemarks.isNotEmpty 
          ? (placemarks.first.country ?? 'Indonesia')
          : 'Indonesia',
        'original_address': address,
        'geocode_method': 'reverse_geocoding'
      };
    } catch (unexpectedError) {
      print('Unexpected geocoding error: $unexpectedError');
      
      // Absolute fallback
      return {
        'latitude': -6.9175,
        'longitude': 107.6191,
        'city': 'Bandung',
        'state': 'Jawa Barat',
        'country': 'Indonesia',
        'original_address': address,
        'geocode_method': 'absolute_fallback'
      };
    }
  }

  // Advanced address validation
  Future<Map<String, dynamic>> validateAddress(String? address) async {
    // Null and empty checks
    if (address == null || address.trim().isEmpty) {
      return {
        'is_valid': false,
        'error': 'Address cannot be null or empty'
      };
    }

    try {
      // Geocode the address
      final geocodeResult = await geocodeAddress(address.trim());

      return {
        'is_valid': true,
        'latitude': geocodeResult['latitude'],
        'longitude': geocodeResult['longitude'],
        'street': address,
        'city': geocodeResult['city'],
        'state': geocodeResult['state'],
        'country': geocodeResult['country'],
        'original_address': geocodeResult['original_address']
      };
    } catch (e) {
      print('Address validation error: $e');
      return {
        'is_valid': false,
        'error': 'Failed to validate address: ${e.toString()}'
      };
    }
  }

  // Add a new address with advanced validation and geolocation
  Future<Map<String, dynamic>?> addAddress({
    required String userId,
    required String label,
    required String address,
    required String recipient,
    required String phone,
    AddressType addressType = AddressType.home,
    bool isDefault = false,
  }) async {
    try {
      // Validate address with comprehensive checks
      final validationResult = await validateAddress(address);
      
      // Always allow address addition, even with limited geocoding
      if (!validationResult['is_valid']) {
        print('Warning: Address validation returned false. Using fallback data.');
      }

      // If setting as default, update other addresses
      if (isDefault) {
        await _supabase
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      // Prepare address data with geolocation
      final addressData = {
        'user_id': userId,
        'label': label,
        'address': validationResult['original_address'] ?? address,
        'recipient': recipient,
        'phone': phone,
        'is_default': isDefault,
        'address_type': addressType.toString().split('.').last,
        'latitude': validationResult['latitude'] ?? -6.9175,  // Bandung default
        'longitude': validationResult['longitude'] ?? 107.6191,
        'city': validationResult['city'] ?? 'Bandung',
        'state': validationResult['state'] ?? 'Jawa Barat',
        'country': validationResult['country'] ?? 'Indonesia',
        'postal_code': '', // Optional field
      };

      final response = await _supabase
          .from('addresses')
          .insert(addressData)
          .select()
          .single();
      
      return response;
    } on PostgrestException catch (e) {
      _logError('Address Add Error', e);
      throw Exception('Failed to add address: ${e.message}');
    } catch (e) {
      _logError('Unexpected Address Add Error', e);
      rethrow;
    }
  }

  // Fetch all addresses for a user
  Future<List<Map<String, dynamic>>> getUserAddresses(String userId) async {
    try {
      final response = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      _logError('Address Fetch Error', e);
      return [];
    } catch (e) {
      _logError('Unexpected Address Fetch Error', e);
      return [];
    }
  }

  // Find nearby addresses within a specified radius
  Future<List<Map<String, dynamic>>> findNearbyAddresses({
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) async {
    try {
      // Use Supabase's postgis extension for geospatial queries
      final response = await _supabase.rpc('find_nearby_addresses', params: {
        'input_latitude': latitude,
        'input_longitude': longitude,
        'max_distance': radiusInKm * 1000  // Convert km to meters
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logError('Nearby Addresses Error', e);
      return [];
    }
  }

  // Get user's default address
  Future<Map<String, dynamic>?> getDefaultAddress(String userId) async {
    try {
      final response = await _supabase
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .single();
      
      return response;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {  // No rows returned
        return null;
      }
      _logError('Default Address Fetch Error', e);
      return null;
    }
  }

  // Update an existing address
  Future<Map<String, dynamic>?> updateAddress({
    required String addressId,
    required String userId,
    String? label,
    String? address,
    String? recipient,
    String? phone,
    bool? isDefault,
  }) async {
    try {
      // Validate input
      if (addressId.isEmpty || userId.isEmpty) {
        throw ArgumentError('Address ID and User ID cannot be empty');
      }

      // If setting as default, update other addresses
      if (isDefault == true) {
        print('Preparing to update other addresses to non-default for user: $userId');
        final updateResponse = await _supabase
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
        print('Updated other addresses to non-default: $updateResponse');
      }

      // Prepare update data
      final updateData = <String, dynamic>{};
      if (label != null) updateData['label'] = label;
      if (address != null) updateData['address'] = address;
      if (recipient != null) updateData['recipient'] = recipient;
      if (phone != null) updateData['phone'] = phone;
      if (isDefault != null) updateData['is_default'] = isDefault;

      print('Updating address $addressId with data: $updateData');

      // Perform the update
      final response = await _supabase
          .from('addresses')
          .update(updateData)
          .eq('id', addressId)
          .eq('user_id', userId)
          .select()
          .single();
      
      print('Address updated successfully: $response');
      return response;
    } on PostgrestException catch (e) {
      print('Supabase Error updating address: ${e.message}');
      _logError('Address Update Error', e);
      throw Exception('Failed to update address: ${e.message}');
    } catch (e) {
      print('Unexpected error updating address: $e');
      _logError('Unexpected Address Update Error', e);
      rethrow;
    }
  }

  // Delete an address
  Future<void> deleteAddress({
    required String addressId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('addresses')
          .delete()
          .eq('id', addressId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      _logError('Address Delete Error', e);
      throw Exception('Failed to delete address: ${e.message}');
    } catch (e) {
      _logError('Unexpected Address Delete Error', e);
      rethrow;
    }
  }

  // Log error helper method
  void _logError(String context, dynamic error) {
    if (kDebugMode) {
      print('$context: $error');
    }
  }
}
