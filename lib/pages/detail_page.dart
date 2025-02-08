import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import 'package:intl/intl.dart';

class DetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const DetailPage({Key? key, required this.product}) : super(key: key);

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final Logger _logger = Logger('DetailPage');
  final supabase = Supabase.instance.client;

  final TextEditingController commentController = TextEditingController();
  double userRating = 0.0;
  List<Map<String, dynamic>> comments = [];
  bool isLoading = false;
  int _quantity = 1;

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    setState(() {
      if (_quantity > 1) {
        _quantity--;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Use a more explicit join and select
      final commentsResponse = await supabase
          .from('reviews')
          .select('*, user:users!reviews_user_id_fkey(name)')
          .eq('product_id', widget.product['id'])
          .order('created_at', ascending: false);

      // Safely convert response to list
      final List<dynamic> responseList =
          commentsResponse is List ? commentsResponse : [commentsResponse];

      if (mounted) {
        setState(() {
          comments = responseList.map((comment) {
            return {
              'id': comment['id']?.toString() ?? '',
              'user_name': comment['user']?['name']?.toString() ?? 'Anonymous',
              'rating': (comment['rating'] is num
                  ? (comment['rating'] as num).toDouble()
                  : double.tryParse(comment['rating']?.toString() ?? '0') ??
                      0.0),
              'comment': comment['comment']?.toString() ?? '',
              'created_at': comment['created_at']?.toString() ?? '',
            };
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error fetching comments', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat komentar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _addToCart() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      _logger.i('[DetailPage] Adding to cart - User ID: $userId');
      _logger.i('[DetailPage] Product details: ${widget.product}');
      _logger.i('[DetailPage] Product Price: ${widget.product['price']}');

      // First, try to find an existing draft order
      final orderResponse = await supabase
          .from('orders')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'draft')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String orderId;
      if (orderResponse == null) {
        // Create a new draft order if no existing order
        final newOrderResponse = await supabase
            .from('orders')
            .insert({
              'user_id': userId,
              'status': 'draft',
              'total_price': 0,
            })
            .select('id')
            .single();
        orderId = newOrderResponse['id'];
        _logger.i('[DetailPage] Created new draft order: $orderId');
      } else {
        orderId = orderResponse['id'];
        _logger.i('[DetailPage] Found existing draft order: $orderId');
      }

      // Check if item already exists in the cart
      final existingItemResponse = await supabase
          .from('order_items')
          .select('id, quantity')
          .eq('order_id', orderId)
          .eq('product_id', widget.product['id'])
          .is_('deleted_at', null)
          .maybeSingle();

      _logger.i('[DetailPage] Existing item response: $existingItemResponse');

      if (existingItemResponse != null) {
        // Update existing item quantity
        await supabase
            .from('order_items')
            .update({
              'quantity': existingItemResponse['quantity'] + _quantity,
            })
            .eq('id', existingItemResponse['id']);
        
        _logger.i('[DetailPage] Updated existing cart item');
      } else {
        // Insert new cart item
        final insertResponse = await supabase
            .from('order_items')
            .insert({
              'order_id': orderId,
              'product_id': widget.product['id'],
              'quantity': _quantity,
              'price': widget.product['price'],
            })
            .select();

        _logger.i('[DetailPage] Inserted new cart item: $insertResponse');
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.product['name']} ditambahkan ke keranjang'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      _logger.e('[DetailPage] Error adding to cart', 
        error: e, 
        stackTrace: stackTrace
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan ke keranjang: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan login terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await supabase.from('reviews').insert({
        'user_id': userId,
        'product_id': widget.product['id'],
        'rating': userRating,
        'comment': commentController.text,
      });

      // Clear input fields
      commentController.clear();
      setState(() {
        userRating = 0.0;
      });

      // Refresh comments
      await _fetchComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ulasan berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error submitting review', error: e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim ulasan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageUrl = SupabaseService.client.storage
        .from('product_images')
        .getPublicUrl(product['image_path'] ?? '');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                product['name'] ?? 'Detail Produk',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black54,
                      offset: Offset(1.0, 1.0),
                    )
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Hero(
                tag: 'product_image_${product['id']}',
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 50),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(product['price'])}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${product['rating']?.toStringAsFixed(1) ?? '0.0'} (${product['total_sold'] ?? 0} terjual)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Deskripsi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['description'] ?? 'Tidak ada deskripsi tersedia.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Jumlah',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: _decrementQuantity,
                            ),
                            Text(
                              '$_quantity',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _incrementQuantity,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Tambah ke Keranjang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reviews Section
                  _buildReviewSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ulasan Produk',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Review Input Section
        _buildReviewInputSection(),
        
        const SizedBox(height: 16),
        
        // Existing Reviews
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (comments.isEmpty)
          Text(
            'Belum ada ulasan',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            comment['user_name'],
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (starIndex) => Icon(
                                starIndex < comment['rating']
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comment['comment'],
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildReviewInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berikan Ulasan Anda',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) => IconButton(
                  icon: Icon(
                    index < userRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      userRating = index + 1.0;
                    });
                  },
                ),
              ),
            ),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                hintText: 'Tulis ulasan Anda...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _submitReview,
              child: const Text('Kirim Ulasan'),
            ),
          ],
        ),
      ),
    );
  }
}
