import 'package:flutter/material.dart';
import 'package:ucv_restaurant/services/product_service.dart';
import 'package:provider/provider.dart';
import '../cart.dart';

class SearchResultsPage extends StatefulWidget {
  final String searchTerm;
  const SearchResultsPage({super.key, required this.searchTerm});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final ProductService _productService = ProductService();
  late Future<List<Map<String, dynamic>>> _searchResults;

  @override
  void initState() {
    super.initState();
    _searchResults = _getResults();
  }

  Future<List<Map<String, dynamic>>> _getResults() async {
    final allProducts = await _productService.getAllProductsOnce();
    return allProducts
        .where(
          (product) => product['name'].toString().toLowerCase().contains(
            widget.searchTerm.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados de búsqueda'),
        backgroundColor: Colors.amber,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _searchResults,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No se encontraron productos.'));
          }

          final results = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: Image.network(item['image'], width: 50, height: 50),
                  title: Text(item['name']),
                  subtitle: Text('S/ ${item['price'].toStringAsFixed(2)}'),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Provider.of<Cart>(context, listen: false).addToCart(item);

                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              '${item['name']} agregado al carrito',
                            ),
                            duration: const Duration(milliseconds: 800),
                          ),
                        );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}