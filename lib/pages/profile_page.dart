import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_page.dart';
import 'package:path/path.dart' as path;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
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
  File? _selectedProfilePicture;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with empty strings
    _nameController = TextEditingController(text: '');
    _emailController = TextEditingController(text: '');
    _phoneController = TextEditingController(text: '');
    _addressController = TextEditingController(text: '');

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
            if (!mounted) return;
            setState(() {
              // Update controllers with fetched data or keep empty
              _nameController.text = profile?['name'] ?? '';
              _emailController.text = user.email ?? '';
              _phoneController.text = profile?['phone'] ?? '';
              _addressController.text = profile?['address'] ?? '';
              _profilePictureUrl = profile?['profile_picture'];
              
              _isLoading = false;
            });
          });
        });
      } else {
        // No user found, ensure loading state is stopped
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
        fileSize = 0;
      }

      const maxFileSize = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxFileSize) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
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
        const SnackBar(
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
      
      // If no profile found, return early
      if (updatedProfile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No profile data found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Safely update state
      if (!mounted) return;
      setState(() {
        _profilePictureUrl = updatedProfile['profile_picture'] ?? _profilePictureUrl;
        
        // Update text controllers if needed, with null-safe defaults
        _nameController.text = updatedProfile['name'] ?? _nameController.text;
        _phoneController.text = updatedProfile['phone'] ?? _phoneController.text;
        _addressController.text = updatedProfile['address'] ?? _addressController.text;
      });
    } catch (e) {
      // Check mounted before showing SnackBar
      if (!mounted) return;
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
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _logout() async {
    // Show logout confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    // Proceed only if confirmed
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Perform logout
      await _authService.signOut();

      // Navigate to login page and remove all previous routes
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      // Handle logout errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exitApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi'),
        content: const Text('Apakah Anda yakin ingin menutup aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    // Exit application if confirmed
    if (confirmed == true) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitApplication,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
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
                            ? const Icon(
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
                              icon: const Icon(
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _uploadProfilePicture,
                      child: const Text('Upload Profile Picture'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    enabled: false, // Email cannot be changed
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Save Profile'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _exitApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.exit_to_app),
                        const SizedBox(width: 8),
                        const Text('Keluar Aplikasi'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    // Dispose of controllers to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
