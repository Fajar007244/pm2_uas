import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../services/supabase_service.dart';
import 'drink_grid_page.dart';
import 'dessert_grid_page.dart';

class PaketGridPage extends StatefulWidget {
  const PaketGridPage({super.key});

  @override
  _PaketGridPageState createState() => _PaketGridPageState();
}

class _PaketGridPageState extends State<PaketGridPage> {
  final Logger _logger = Logger('PaketGridPage');
  List<Map<String, dynamic>> _paketItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPaketItems();
  }

  Future<void> _fetchPaketItems() async {
    try {
      final response = await SupabaseService.client
          .from('products')
          .select('id, name, description, price, image_path, categories!inner(name)')
          .eq('categories.name', 'Paket')
          .order('created_at', ascending: false);

      final List<dynamic> responseList = response is List ? response : [response];
      
      setState(() {
        _paketItems = responseList.map((item) {
          final category = item['categories'] is List 
              ? (item['categories'] as List).firstOrNull 
              : item['categories'];
          
          return {
            'id': item['id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'description': item['description']?.toString() ?? '',
            'price': (item['price'] is num 
              ? (item['price'] as num).toDouble() 
              : double.tryParse(item['price']?.toString() ?? '0') ?? 0.0),
            'image_path': item['image_path']?.toString() ?? '',
            'category': category?['name']?.toString() ?? '',
            'rating': 4.5, // Placeholder
            'total_sold': 100, // Placeholder
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _logger.e('Error fetching paket items', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat paket: ${e.toString()}')),
      );
    }
  }

  String _getProductImageUrl(String imagePath) {
    return SupabaseService.client.storage.from('product_images').getPublicUrl(imagePath);
  }

  void _navigateToDetailPage(Map<String, dynamic> product) {
    Navigator.pushNamed(
      context, 
      '/detail', 
      arguments: product,
    );
  }

  Widget _buildRatingAndSoldWidget(Map<String, dynamic> product) {
    return Row(
      children: [
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 14,
        ),
        const SizedBox(width: 2),
        Text(
          '${product['rating']} | ${product['total_sold']} terjual',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderButton(Map<String, dynamic> product) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 25,
          child: ElevatedButton(
            onPressed: () => _navigateToDetailPage(product),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Pesan',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(Map<String, dynamic> product) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Image.network(
              _getProductImageUrl(product['image_path']),
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 130,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${product['price']}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                _buildRatingAndSoldWidget(product),
                const SizedBox(height: 2),
                _buildOrderButton(product),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Menu SiKotak'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Paket'),
              Tab(text: 'Minuman'),
              Tab(text: 'Dessert'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Paket Tab
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _paketItems.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada paket tersedia',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: _paketItems.length,
                        itemBuilder: (context, index) {
                          final product = _paketItems[index];
                          return GestureDetector(
                            onTap: () => _navigateToDetailPage(product),
                            child: _buildGridItem(product),
                          );
                        },
                      ),
            // Minuman Tab
            const DrinkGridPage(),
            // Dessert Tab
            const DessertGridPage(),
          ],
        ),
      ),
    );
  }
}
