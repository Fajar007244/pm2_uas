// Global data and constants for the application

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

// Address Management
List<Map<String, dynamic>> addresses = [
  {
    'id': '1',
    'label': 'Rumah',
    'address': 'Jl. Admin No. 1',
    'recipient': 'Admin',
    'phone': '08123456789',
    'isDefault': true,
  }
];

// Notifications
List<Map<String, dynamic>> notifications = [
  {
    'id': '1',
    'title': 'Selamat Datang!',
    'message': 'Nikmati promo spesial untuk pengguna baru',
    'timestamp': DateTime.now(),
    'isRead': false,
  }
];

Map<String, dynamic>? currentUser;
