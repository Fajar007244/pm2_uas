import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class OrderDetailPage extends StatefulWidget {
  final dynamic order;

  const OrderDetailPage({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Map<String, dynamic> order;
  bool _isLoading = true;
  String _errorMessage = '';
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    order = _convertToMap(widget.order);
    _fetchOrderDetails();
  }

  Map<String, dynamic> _convertToMap(dynamic input) {
    if (input is Map<String, dynamic>) {
      return input;
    } else if (input is Map) {
      return input.map((key, value) => MapEntry(key.toString(), value));
    } else {
      _logger.w('Unexpected order type: ${input.runtimeType}');
      return {};
    }
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final orderId = order['id']?.toString();
      if (orderId == null) {
        throw Exception('Invalid order ID');
      }

      final response = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('id', orderId)
          .single();

      setState(() {
        order = _convertToMap(response);
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error fetching order details', error: e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat detail pesanan: ${e.toString()}';
      });
    }
  }

  double _calculateTotalPrice() {
    try {
      final items = order['order_items'] ?? [];

      if (order['total_price'] != null) {
        return double.tryParse(order['total_price'].toString()) ?? 0.0;
      }

      return (items as List).fold(0.0, (total, item) {
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        return total + (price * quantity);
      });
    } catch (e) {
      _logger.e('Error calculating total price', error: e);
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pesanan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pesanan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 100,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchOrderDetails,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final status = order['status'] ?? 'Unknown';
    final createdAt = order['created_at'] ?? '';
    final orderItems = order['order_items'] ?? [];
    final totalPrice = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pesanan #${order['id'].substring(0, 8)}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pesanan #${order['id'].substring(0, 8)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (orderItems.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 100,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada produk dalam pesanan',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            Card(
              elevation: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Produk Dipesan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orderItems.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = orderItems[index];
                      final product = item['products'] ?? {};
                      final price =
                          double.tryParse(item['price']?.toString() ?? '0') ??
                              0.0;
                      final quantity =
                          int.tryParse(item['quantity']?.toString() ?? '1') ??
                              1;

                      return ListTile(
                        leading: _buildProductImage(product['image_path']),
                        title: Text(
                          product['name'] ?? 'Produk Tidak Dikenal',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'Rp ${price.toStringAsFixed(0)} x $quantity',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: Text(
                          'Rp ${(price * quantity).toStringAsFixed(0)}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pembayaran',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rp ${totalPrice.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return '${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return months[month - 1];
  }

  String _getProductImageUrl(String imagePath) {
    return Supabase.instance.client.storage.from('product_images').getPublicUrl(imagePath);
  }

  Widget _buildProductImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Icon(Icons.image_not_supported, size: 80);
    }

    final imageUrl = _getProductImageUrl(imagePath);

    return Image.network(
      imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        _logger.e('Image load error: $error');
        return const Icon(Icons.image_not_supported, size: 80);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            value: null,
            strokeWidth: 2,
          ),
        );
      },
    );
  }
}
