import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;
import 'services/supabase_service.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'pages/cart_page.dart';
import 'pages/paket_grid_page.dart';
import 'pages/drink_grid_page.dart';
import 'pages/dessert_grid_page.dart';
import 'pages/order_history_page.dart';
import 'pages/address_list_page.dart';
import 'pages/notifications_page.dart';
import 'pages/detail_page.dart';
import 'pages/order_detail_page.dart';

List<Map<String, dynamic>> cart = [];
List<Map<String, dynamic>> orderHistory = [];
List<Map<String, dynamic>> users = [
  {
    'email': 'admin@gmail.com',
    'password': 'admin123',
    'name': 'Admin',
    'phone': '08123456789',
    'address': 'Jl. Admin No. 1'
  }
];

Map<String, dynamic>? currentUser;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation Controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Scale Animation (Subtle Bounce)
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Fade Animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start Animation
    _animationController.forward();

    // Navigate to Login Page
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration(milliseconds: 500), () {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AuthWrapper(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: Duration(milliseconds: 800),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange[50]?.withOpacity(0.9),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo with Scale and Shadow
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange[50]?.withOpacity(0.9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            spreadRadius: 10,
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 72,
                        color: Colors.orange.withOpacity(1),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Animated Text with Fade
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    children: [
                      Text(
                        "SiKotak",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.orange[700]?.withOpacity(0.9),
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.orange.withOpacity(0.2),
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Santap Nikmat Tanpa Ribet",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800]?.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 48),

                // Loading Indicator
                Opacity(
                  opacity: _fadeAnimation.value,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    strokeWidth: 4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    final supabase = SupabaseService.client;
    setState(() {
      _isAuthenticated = supabase.auth.currentSession != null;
    });

    supabase.auth.onAuthStateChange.listen((data) {
      setState(() {
        _isAuthenticated = data.session != null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated ? const HomePage() : const LoginPage();
  }
}

class SiKotakApp extends StatelessWidget {
  const SiKotakApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiKotak',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/cart': (context) => const CartPage(),
        '/paket': (context) => const PaketGridPage(),
        '/drinks': (context) => const DrinkGridPage(),
        '/desserts': (context) => const DessertGridPage(),
        '/order-history': (context) => const OrderHistoryPage(),
        '/addresses': (context) => const AddressListPage(),
        '/notifications': (context) => const NotificationsPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/detail') {
          final product = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => DetailPage(key: const Key('detail'), product: product),
          );
        } else if (settings.name == '/order_detail') {
          final order = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => OrderDetailPage(order: order),
          );
        }
        return null;
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse) {
    runApp(const SiKotakApp());
  } else {
    developer.log('Location permissions are required for this app to function.',
        name: 'main', level: 1000 // WARNING level
        );
    runApp(const SiKotakApp());
  }
}
