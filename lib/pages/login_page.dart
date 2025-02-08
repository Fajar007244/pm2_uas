import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/global_data.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _login() async {
    // Validate email and password
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Email tidak boleh kosong');
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Password tidak boleh kosong');
      return;
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showErrorDialog('Error', 'Format email tidak valid');
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final supabase = Supabase.instance.client;

      print('Attempting login with email: ${_emailController.text.trim()}'); // Debug print

      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Remove loading indicator
      Navigator.of(context, rootNavigator: true).pop();

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      // Verify user exists
      if (response.user != null) {
        try {
          // Update global user data safely
          currentUser = {
            'id': response.user!.id,
            'email': response.user!.email,
            // Add more user details as needed
          };

          // Navigate to home page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        } catch (e) {
          _showErrorDialog('Login Error', 'Gagal memuat data pengguna: ${e.toString()}');
        }
      }
    } on AuthException catch (e) {
      // Remove loading indicator
      Navigator.of(context, rootNavigator: true).pop();

      // Log detailed error information
      print('Authentication Error: ${e.message}'); // Debug print
      print('Authentication Error Type: ${e.runtimeType}'); // Debug print

      // Handle specific Supabase authentication errors
      String errorMessage = 'Login gagal';
      switch (e.message.toLowerCase()) {
        case 'invalid login credentials':
          errorMessage = 'Email atau password salah';
          break;
        case 'user not found':
          errorMessage = 'Pengguna tidak ditemukan';
          break;
        case 'invalid email format':
          errorMessage = 'Format email tidak valid';
          break;
        default:
          errorMessage = e.message;
      }

      _showErrorDialog('Login Error', errorMessage);
    } catch (e) {
      // Remove loading indicator
      Navigator.of(context, rootNavigator: true).pop();

      // Log unexpected errors
      print('Unexpected Login Error: $e'); // Debug print
      _showErrorDialog('Login Error', 'Terjadi kesalahan tidak terduga: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _register() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController _resetEmailController =
            TextEditingController();
        return AlertDialog(
          title: Text('Lupa Password'),
          content: TextField(
            controller: _resetEmailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Kirim'),
              onPressed: () async {
                // Validate email
                final email = _resetEmailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Masukkan email yang valid'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final supabase = Supabase.instance.client;
                  await supabase.auth.resetPasswordForEmail(
                    email,
                    redirectTo:
                        'your-app-reset-password-url', // Replace with your app's reset URL
                  );

                  // Close current dialog and show success
                  Navigator.of(context).pop();
                  _showErrorDialog(
                    'Reset Password',
                    'Link reset password telah dikirim ke email Anda.',
                  );
                } catch (e) {
                  // Show error dialog
                  _showErrorDialog(
                    'Error',
                    'Gagal mengirim link reset password: $e',
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange,
                          ),
                          child: Icon(
                            Icons.login,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Selamat Datang',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Silakan Login Untuk Melanjutkan Ke Aplikasi',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Masukkan email';
                            }
                            if (!value.contains('@')) {
                              return 'Masukkan email yang valid';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Masukkan password';
                            }
                            if (value.length < 6) {
                              return 'Password minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: Text(
                              'Lupa Password?',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Login',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Belum punya akun?'),
                            TextButton(
                              onPressed: _register,
                              child: Text(
                                'Daftar',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
