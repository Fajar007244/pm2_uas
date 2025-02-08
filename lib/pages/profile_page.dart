import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_page.dart';
import 'package:path/path.dart' as path;

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  
  bool _isLoading = false;
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  File? _selectedProfilePicture;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserProfile();
    });
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get current authenticated user
      final user = _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          
          // Fetch user profile
          _profileService.getProfile(user.id).then((profile) {
            setState(() {
              _userProfile = profile;
              
              // Initialize controllers with fetched data
              _nameController = TextEditingController(text: profile?['name'] ?? '');
              _emailController = TextEditingController(text: user.email ?? '');
              _phoneController = TextEditingController(text: profile?['phone'] ?? '');
              _addressController = TextEditingController(text: profile?['address'] ?? '');
              _profilePictureUrl = profile?['profile_picture'];
              
              _isLoading = false;
            });
          });
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching profile: $e')),
      );
    }
  }

  Future<void> _selectProfilePicture() async {
    try {
      // Attempt to pick an image
      final pickedFile = await _profileService.pickProfilePicture();
      
      if (pickedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No image was selected'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Attempt to create a file object with robust error handling
      File? selectedFile;
      try {
        selectedFile = File(pickedFile.path);
      } catch (e) {
        print('File conversion error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not process the selected image'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate file size
      int fileSize = 0;
      try {
        fileSize = await selectedFile.length();
      } catch (e) {
        print('File size check error: $e');
        fileSize = 0;
      }

      const maxFileSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxFileSize) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File is too large. Maximum size is 5MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate file type
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif'];
      final fileExtension = path.extension(selectedFile.path).toLowerCase();
      if (!allowedExtensions.contains(fileExtension)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid file type. Only JPG, PNG, and GIF are allowed.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _selectedProfilePicture = selectedFile;
      });

      // Trigger upload
      await _uploadProfilePicture();
    } catch (e) {
      // More detailed error handling
      String errorMessage = 'Error selecting profile picture';
      
      if (e.toString().contains('Unsupported operation') || 
          e.toString().contains('_Namespace')) {
        errorMessage = 'Image selection is not supported on this platform.';
      } else if (e.toString().contains('File is too large')) {
        errorMessage = 'Image is too large. Maximum size is 5MB.';
      } else if (e.toString().contains('Invalid file type')) {
        errorMessage = 'Invalid file type. Only JPG, PNG, and GIF are allowed.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );

      // Log the full error for debugging
      print('Profile Picture Selection Error: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_currentUser == null || _selectedProfilePicture == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload profile picture
      final uploadedUrl = await _profileService.uploadProfilePicture(
        userId: _currentUser!.id, 
        imageFile: _selectedProfilePicture!,
      );

      // Verify the uploaded URL is not empty
      if (uploadedUrl.isEmpty) {
        throw Exception('Failed to get a valid profile picture URL');
      }

      // Fetch the updated user profile to ensure we have the latest data
      await _refreshUserProfile();

      setState(() {
        _selectedProfilePicture = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile picture updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile picture: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshUserProfile() async {
    try {
      if (_currentUser == null) return;

      // Fetch updated user profile
      final updatedProfile = await _profileService.getProfile(_currentUser!.id);
      
      setState(() {
        _userProfile = updatedProfile;
        _profilePictureUrl = updatedProfile?['profile_picture'];
        
        // Update text controllers if needed
        _nameController.text = updatedProfile?['name'] ?? '';
        _phoneController.text = updatedProfile?['phone'] ?? '';
        _addressController.text = updatedProfile?['address'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Update profile using Supabase
      final updatedProfile = await _profileService.upsertProfile(
        id: _currentUser!.id,
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        address: _addressController.text,
      );

      // Upload profile picture if selected
      if (_selectedProfilePicture != null) {
        await _uploadProfilePicture();
      }

      setState(() {
        _userProfile = updatedProfile;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        // Profile Picture
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.orange,
                          backgroundImage: _selectedProfilePicture != null
                            ? FileImage(_selectedProfilePicture!)
                            : (_profilePictureUrl != null
                              ? NetworkImage(_profilePictureUrl!)
                              : null),
                          child: _selectedProfilePicture == null && 
                                 _profilePictureUrl == null
                            ? Icon(
                                Icons.person, 
                                size: 60, 
                                color: Colors.white
                              )
                            : null,
                        ),
                        // Edit Profile Picture Button
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: Icon(
                                Icons.edit, 
                                color: Colors.orange,
                                size: 20,
                              ),
                              onPressed: _selectProfilePicture,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Show upload button if a new picture is selected
                  if (_selectedProfilePicture != null) ...[
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _uploadProfilePicture,
                      child: Text('Upload Profile Picture'),
                    ),
                  ],
                  SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    enabled: false, // Email cannot be changed
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    child: Text('Save Profile'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
