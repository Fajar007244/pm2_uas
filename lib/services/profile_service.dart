import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class ProfileService {
  static final _supabase = Supabase.instance.client;

  // Fetch user profile
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();

      return response;
    } on PostgrestException catch (e) {
      _logError('Profile Fetch Error', e);
      if (e.code == 'PGRST116') {
        // No profile found
        return null;
      }
      rethrow;
    } catch (e) {
      _logError('Unexpected Profile Fetch Error', e);
      rethrow;
    }
  }

  // Create or update user profile
  Future<Map<String, dynamic>> upsertProfile({
    required String id,
    required String name,
    required String email,
    String? phone,
    String? address,
  }) async {
    try {
      final serviceRoleSupabase = SupabaseClient(
          'https://ozllkmkouqbjteayjcyy.supabase.co',
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96bGxrbWtvdXFianRlYXlqY3l5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNDMxMTIzOSwiZXhwIjoyMDQ5ODg3MjM5fQ.pESoDBj4u4dShJaU_a2L_6kFS5iopLcbvp1lypFvMm8' // You must replace this with your actual service role key
          );

      final response = await serviceRoleSupabase
          .from('users')
          .upsert({
            'id': id,
            'name': name,
            'email': email,
            'phone': phone,
            'address': address,
          })
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      _logError('Profile Update Error', e);
      throw Exception('Failed to update profile: ${e.message}');
    } catch (e) {
      _logError('Unexpected Profile Update Error', e);
      rethrow;
    }
  }

  // Fetch user profile by ID
  Future<UserProfile> fetchUserProfile(String userId) async {
    try {
      // Fetch user profile from the database
      final response = await _supabase
          .from('users')
          .select('id, name, email, profile_picture')
          .eq('id', userId)
          .single();

      // Create and return a UserProfile object
      return UserProfile(
        id: response['id'],
        name: response['name'] ?? '',
        email: response['email'] ?? '',
        profilePictureUrl: response['profile_picture'],
      );
    } catch (e) {
      print('Error fetching user profile: $e');
      
      // Provide a fallback or rethrow the error
      if (e is PostgrestException && e.code == 'PGRST116') {
        throw Exception('User profile not found');
      }
      
      rethrow;
    }
  }

  // Upload profile picture with robust image processing
  Future<String> uploadProfilePicture({
    required String userId,
    required dynamic imageFile, // Use dynamic to support different file types
  }) async {
    try {
      // Determine file extension and content type
      String fileExtension = '';
      Uint8List fileBytes;

      // Enhanced file type handling
      if (imageFile is File) {
        // Desktop/Mobile file
        fileExtension = path.extension(imageFile.path);
        fileBytes = await imageFile.readAsBytes();
      } else if (imageFile is XFile) {
        // Cross-platform image picker file
        fileExtension = path.extension(imageFile.path);
        fileBytes = await imageFile.readAsBytes();
      } else if (imageFile is Uint8List) {
        // Web or memory file
        fileBytes = imageFile;
        fileExtension = '.png'; // Default for web/memory files
      } else {
        // Detailed error for unsupported file type
        print('Unsupported file type: ${imageFile.runtimeType}');
        throw ArgumentError('Unsupported file type: ${imageFile.runtimeType}');
      }

      // Validate file extension
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif'];
      if (!allowedExtensions.contains(fileExtension.toLowerCase())) {
        throw ArgumentError('Invalid file type. Only JPG, PNG, and GIF are allowed.');
      }

      // Validate file size
      if (fileBytes.length > 5 * 1024 * 1024) { // 5MB limit
        throw ArgumentError('File is too large. Maximum size is 5MB.');
      }

      // Validate and process image
      Uint8List processedBytes = await _processImage(fileBytes, fileExtension);

      // Generate a unique filename
      final fileName = '$userId$fileExtension';
      final filePath = 'profile_pictures/$fileName';

      // Upload the file to Supabase storage
      final storageResponse =
          await _supabase.storage.from('profile_pictures').uploadBinary(
                filePath,
                processedBytes,
                fileOptions: FileOptions(
                  upsert: true, // Overwrite existing file
                  contentType: _getContentType(fileExtension),
                ),
              );

      // Get public URL of the uploaded image
      final publicUrl =
          _supabase.storage.from('profile_pictures').getPublicUrl(filePath);

      // Construct the full public URL
      final fullPublicUrl = publicUrl.contains('https://') 
          ? publicUrl 
          : 'https://ozllkmkouqbjteayjcyy.supabase.co/storage/v1/object/public/$publicUrl';

      // Update user profile with image URL
      final updateResponse = await _supabase
          .from('users')
          .update({'profile_picture': fullPublicUrl}).eq('id', userId);

      return fullPublicUrl;
    } catch (e, stackTrace) {
      // Comprehensive error logging
      print('Profile Picture Upload Error:');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('Stacktrace: $stackTrace');

      // Specific error handling
      if (e is ArgumentError) {
        throw Exception(e.message);
      } else if (e.toString().contains('Unsupported operation')) {
        throw Exception('Unsupported file operation. Please try a different image.');
      }

      // Generic error fallback
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  // Pick image from gallery with cross-platform support
  Future<dynamic> pickProfilePicture() async {
    final ImagePicker picker = ImagePicker();

    try {
      // Detailed platform logging
      print('Platform Details:');
      print('Platform: ${Platform.operatingSystem}');
      print('Platform Version: ${Platform.operatingSystemVersion}');
      print('Dart Version: ${Platform.version}');

      // Attempt to pick an image with comprehensive error handling
      XFile? pickedFile;
      try {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
      } catch (e) {
        print('Image Picker Error (First Attempt): $e');
        
        // Fallback method for web or problematic platforms
        try {
          pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
          );
        } catch (fallbackError) {
          print('Image Picker Fallback Error: $fallbackError');
          throw Exception('Failed to pick image: ${fallbackError.toString()}');
        }
      }

      // Validate picked file
      if (pickedFile == null) {
        print('No image was picked');
        return null;
      }

      // Additional file validation
      print('Picked File Details:');
      print('Path: ${pickedFile.path}');
      print('Name: ${pickedFile.name}');
      
      // Attempt to get file size
      try {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        print('File Size: $fileSize bytes');
      } catch (sizeError) {
        print('Could not determine file size: $sizeError');
      }

      return pickedFile;
    } catch (e, stackTrace) {
      // Comprehensive error logging
      print('Profile Picture Selection Error:');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('Stacktrace: $stackTrace');

      // Specific error handling
      if (e.toString().contains('_Namespace') || 
          e.toString().contains('Unsupported operation')) {
        throw Exception('Image selection is not supported on this platform. Please try a different method.');
      }

      // Generic error fallback
      throw Exception('An unexpected error occurred while selecting an image: ${e.toString()}');
    }
  }

  // Robust image processing method
  Future<Uint8List> _processImage(
      Uint8List imageBytes, String extension) async {
    try {
      // Decode the image
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Resize and compress the image
      img.Image resizedImage = img.copyResize(originalImage,
          width: 1024, // Max width
          height: 1024, // Max height
          interpolation: img.Interpolation.average);

      // Compress the image with a specific quality
      Uint8List compressedBytes;
      switch (extension.toLowerCase()) {
        case '.jpg':
        case '.jpeg':
          compressedBytes =
              Uint8List.fromList(img.encodeJpg(resizedImage, quality: 80));
          break;
        case '.png':
          compressedBytes = Uint8List.fromList(img.encodePng(resizedImage));
          break;
        default:
          compressedBytes = imageBytes;
      }

      return compressedBytes;
    } catch (e) {
      _logError('Image Processing Error', e);
      // Fallback to original image if processing fails
      return imageBytes;
    }
  }

  // Helper method to get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  // Logging helper method
  void _logError(String context, dynamic error) {
    if (kDebugMode) {
      print('$context: $error');
    }
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? profilePictureUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl,
  });
}
