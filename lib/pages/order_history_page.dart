import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/order_detail_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      
      setState(() {
        _orders = (response as List).map((dynamic orderData) {
          // Ensure orderData is converted to Map<String, dynamic>
          final Map<String, dynamic> order = Map<String, dynamic>.from(orderData);
          
          // Process order items
          final List<dynamic> orderItems = order['order_items'] ?? [];
          final processedOrderItems = orderItems
              .where((dynamic itemData) {
                final Map<String, dynamic> item = Map<String, dynamic>.from(itemData);
                final products = item['products'] ?? {};
                return products.isNotEmpty && 
                       (int.tryParse(item['quantity']?.toString() ?? '0') ?? 0) > 0;
              })
              .map((dynamic itemData) => Map<String, dynamic>.from(itemData))
              .toList();
          
          // Create a new order map with processed items
          return {
            ...order,
            'order_items': processedOrderItems,
            'total_price': _calculateTotalPrice(order),
          };
        }).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching orders: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _calculateTotalPrice(Map<String, dynamic> order) {
    // Prioritize order's total_price
    if (order['total_price'] != null) {
      final totalPrice = double.tryParse(order['total_price'].toString());
      if (totalPrice != null && totalPrice > 0) {
        return totalPrice;
      }
    }

    // Fallback: Calculate from order items
    final items = order['order_items'] ?? [];
    return items.fold(0.0, (total, item) {
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      return total + (price * quantity);
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange.shade200;
      case 'pending':
        return Colors.blue.shade200;
      case 'processing':
        return Colors.yellow.shade200;
      case 'shipped':
        return Colors.purple.shade200;
      case 'completed':
        return Colors.green.shade200;
      case 'cancelled':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'processing':
        return 'Sedang Diproses';
      case 'shipped':
        return 'Sedang Dikirim';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Status Tidak Dikenal';
    }
  }

  String _formatDate(String dateString) {
    try {
      final DateTime dateTime = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 100,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada pesanan',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final totalPrice = order['total_price'];
                      final status = order['status'] ?? 'Unknown';
                      final createdAt = order['created_at'] ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailPage(
                                  order: order,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Pesanan #${order['id'].substring(0, 8)}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status).toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatDate(createdAt),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${order['order_items']?.length ?? 0} Produk',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Total: Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_calculateTotalPrice(order))}',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
