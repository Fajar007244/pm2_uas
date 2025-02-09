import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/address_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Logger _logger = Logger();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  Map<String, bool> _selectedItems = {};
  double _totalPrice = 0.0;
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _fetchCartItems();
    _fetchUserAddresses();
  }

  Future<void> _fetchCartItems() async {
    try {
      setState(() => _isLoading = true);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Fetch draft order items with multiple query strategies
      var response = await supabase
          .from('order_items')
          .select('*, products(*)')
          .eq(
              'order_id',
              (await supabase
                  .from('orders')
                  .select('id')
                  .eq('user_id', userId)
                  .eq('status', 'draft')
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle())['id'])
          .is_('deleted_at', null)
          .eq('products.is_active', true);

      _logger.i('Raw Order Items Response: $response');

      // Process and map order items
      final List<Map<String, dynamic>> cartItems = [];
      for (var item in response) {
        if (item['products'] != null) {
          cartItems.add({
            ...item,
            'id': item['id']?.toString() ?? '',
            'order_id': item['order_id'],
          });
        }
      }

      _logger.i('Processed Cart Items: ${cartItems.length} items');

      setState(() {
        _cartItems = cartItems;

        // Reset selected items based on fetched cart items
        _selectedItems = {
          for (var item in _cartItems) item['id'].toString(): false
        };

        _calculateTotalPrice();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _logger.e('Error fetching cart items', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat keranjang: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() {
        _cartItems = [];
        _selectedItems = {};
        _totalPrice = 0.0;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserAddresses() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final response = await supabase
          .from('addresses')
          .select('*')
          .eq('user_id', userId)
          .order('is_default', ascending: false);

      setState(() {
        _addresses = List<Map<String, dynamic>>.from(response);
        
        // Automatically select the default address if available
        _selectedAddress = _addresses.firstWhere(
          (address) => address['is_default'] == true, 
          orElse: () => _addresses.isNotEmpty ? _addresses.first : <String, dynamic>{}
        );
      });
    } catch (e) {
      _logger.e('Error fetching addresses', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat alamat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateTotalPrice() {
    final total = _cartItems.fold(0.0, (sum, item) {
      // Only calculate total for selected items
      if (_selectedItems[item['id'].toString()] == true) {
        final product = item['products'] ?? {};
        final productPrice =
            double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
        final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        return sum + (productPrice * quantity);
      }
      return sum;
    });

    setState(() {
      _totalPrice = total;
    });
  }

  void _toggleItemSelection(String itemId, bool? value) {
    setState(() {
      _selectedItems[itemId] = value ?? false;
      _calculateTotalPrice();
    });
  }

  Future<void> _updateQuantity(String orderItemId, int newQuantity) async {
    if (newQuantity < 1) {
      await _removeFromCart(orderItemId);
      return;
    }

    try {
      await supabase
          .from('order_items')
          .update({'quantity': newQuantity}).eq('id', orderItemId);

      await _fetchCartItems();
    } catch (e) {
      _logger.e('Error updating quantity', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui kuantitas: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFromCart(String orderItemId) async {
    try {
      await supabase.from('order_items').delete().eq('id', orderItemId);

      await _fetchCartItems();
    } catch (e) {
      _logger.e('Error removing from cart', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createOrder() async {
    // Check if any items are selected
    final selectedItemsCount = _selectedItems.values.where((selected) => selected).length;
    if (selectedItemsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu item untuk membuat pesanan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda akan membuat pesanan dengan:'),
            const SizedBox(height: 8),
            Text('- Jumlah Item: $selectedItemsCount'),
            Text('- Total Harga: Rp ${_totalPrice.toStringAsFixed(0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    // Proceed only if confirmed
    if (confirmed != true) return;

    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih alamat pengiriman'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Create order with selected address details
      final orderResponse = await supabase
          .from('orders')
          .insert({
            'user_id': userId,
            'status': 'pending',
            'total_price': _totalPrice,
            'recipient_name': _selectedAddress!['recipient'] ?? '',
            'recipient_phone': _selectedAddress!['phone'] ?? '',
            'shipping_address': _selectedAddress!['address'] ?? '',
          })
          .select('id')
          .single();

      // Update order items with new order ID
      for (var item in _cartItems) {
        if (_selectedItems[item['id'].toString()] == true) {
          await supabase
              .from('order_items')
              .update({'order_id': orderResponse['id']})
              .eq('id', item['id']);
        }
      }

      // Clear selected items and refresh cart
      await _fetchCartItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibuat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error creating order', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat pesanan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAddressSelection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        title: Text(
          'Alamat Pengiriman',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: _selectedAddress != null
            ? Text(
                '${_selectedAddress!['label']} - ${_selectedAddress!['address']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : const Text('Pilih Alamat'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAddressSelectionBottomSheet(),
      ),
    );
  }

  void _showAddressSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Pilih Alamat Pengiriman',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _addresses.length,
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  return ListTile(
                    title: Text(address['label']),
                    subtitle: Text(address['address']),
                    trailing: _selectedAddress?['id'] == address['id']
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedAddress = address;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to add new address page
                  // You'll need to implement this page
                  Navigator.pop(context);
                },
                child: const Text('Tambah Alamat Baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _constructImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // Use Supabase storage public URL method
    return Supabase.instance.client.storage.from('product_images').getPublicUrl(imagePath);
  }

  Widget _buildProductImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return _buildPlaceholderImage();
    }

    final fullImageUrl = _constructImageUrl(imagePath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: fullImageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildLoadingImage(),
        errorWidget: (context, url, error) {
          _logger.e('Image load error details:', 
            error: {
              'Path': imagePath,
              'Full URL': fullImageUrl,
              'Error': error
            }
          );
          return _buildPlaceholderImage();
        },
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[500],
        size: 30,
      ),
    );
  }

  Widget _buildLoadingImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined, 
                        size: 100, 
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Keranjang kosong',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _buildAddressSelection(),
                      
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: _cartItems.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _cartItems[index];
                            final product = item['products'] ?? {};
                            final itemId = item['id'].toString();

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withAlpha(25), 
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                controlAffinity: ListTileControlAffinity.leading,
                                value: _selectedItems[itemId] ?? false,
                                onChanged: (bool? value) =>
                                    _toggleItemSelection(itemId, value),
                                title: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildProductImage(product['image_path']),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ?? 'Produk Tidak Dikenal',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.grey[800],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Rp ${double.parse(product['price']?.toString() ?? '0').toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                secondary: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _updateQuantity(
                                            itemId,
                                            (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1) - 1,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.remove,
                                              size: 16,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          child: Text(
                                            item['quantity']?.toString() ?? '1',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _updateQuantity(
                                            itemId,
                                            (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1) + 1,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Bottom section for total and checkout
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  'Rp ${_totalPrice.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _selectedItems.values.where((selected) => selected).length > 0 ? _createOrder : null,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.green[700],
                                disabledBackgroundColor: Colors.grey[400],
                              ),
                              child: const Text(
                                'Buat Pesanan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
