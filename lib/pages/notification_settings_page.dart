import 'package:flutter/material.dart';
import '../models/global_data.dart';

class NotificationSettingsPage extends StatefulWidget {
  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Notification preferences
  bool _enablePromotions = true;
  bool _enableOrderUpdates = true;
  bool _enableNewItems = true;

  // Notification filters
  List<String> _notificationCategories = [
    'Semua Notifikasi',
    'Promo',
    'Pesanan',
    'Menu Baru'
  ];
  String _selectedCategory = 'Semua Notifikasi';

  @override
  void initState() {
    super.initState();
    // Load existing preferences (you might want to persist these)
    _enablePromotions = true;
    _enableOrderUpdates = true;
    _enableNewItems = true;
  }

  List<Map<String, dynamic>> _filterNotifications() {
    switch (_selectedCategory) {
      case 'Promo':
        return notifications.where((n) => n['title'].toString().toLowerCase().contains('promo')).toList();
      case 'Pesanan':
        return notifications.where((n) => n['title'].toString().toLowerCase().contains('pesanan')).toList();
      case 'Menu Baru':
        return notifications.where((n) => n['title'].toString().toLowerCase().contains('menu')).toList();
      default:
        return notifications;
    }
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hapus Semua Notifikasi'),
          content: Text('Apakah Anda yakin ingin menghapus semua notifikasi?'),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Hapus'),
              onPressed: () {
                setState(() {
                  notifications.clear();
                });
                Navigator.of(context).pop();
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
      appBar: AppBar(
        title: Text('Pengaturan Notifikasi'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep),
            onPressed: _clearAllNotifications,
            tooltip: 'Hapus Semua Notifikasi',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Notification Preferences Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Preferensi Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: Text('Notifikasi Promo'),
            subtitle: Text('Terima pemberitahuan tentang promo spesial'),
            value: _enablePromotions,
            onChanged: (bool value) {
              setState(() {
                _enablePromotions = value;
              });
            },
          ),
          SwitchListTile(
            title: Text('Notifikasi Status Pesanan'),
            subtitle: Text('Terima pembaruan tentang pesanan Anda'),
            value: _enableOrderUpdates,
            onChanged: (bool value) {
              setState(() {
                _enableOrderUpdates = value;
              });
            },
          ),
          SwitchListTile(
            title: Text('Notifikasi Menu Baru'),
            subtitle: Text('Terima informasi tentang menu terbaru'),
            value: _enableNewItems,
            onChanged: (bool value) {
              setState(() {
                _enableNewItems = value;
              });
            },
          ),

          // Notification Filter Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Filter Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCategory,
              items: _notificationCategories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
            ),
          ),

          // Filtered Notifications Preview
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Pratinjau Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._filterNotifications().map((notification) {
            return ListTile(
              title: Text(notification['title']),
              subtitle: Text(notification['message']),
              trailing: Text(
                _formatTimestamp(notification['timestamp']),
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
