import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../cart.dart';
import 'cart_page.dart';

class BebidasPage extends StatefulWidget {
  final String searchTerm;
  const BebidasPage({super.key, this.searchTerm = ''});

  @override
  State<BebidasPage> createState() => _BebidasPageState();
}

class _BebidasPageState extends State<BebidasPage> {
  final ProductService _productService = ProductService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _productService.getProductsByCategory('Bebidas'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay bebidas disponibles'));
        }

        final productos = snapshot.data!
            .where((p) => p['name']
                .toString()
                .toLowerCase()
                .contains(widget.searchTerm.toLowerCase()))
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Bebidas 🍹',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.pink.shade400,
            actions: [_buildCartIcon()],
          ),
          body: SafeArea(
            child: productos.isEmpty
                ? const Center(child: Text('No se encontraron bebidas'))
                : _buildGrid(productos),
          ),
        );
      },
    );
  }

  /// Icono de carrito
  Widget _buildCartIcon() {
    return Consumer<Cart>(
      builder: (context, cart, _) => Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
          ),
          if (cart.totalQuantity > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${cart.totalQuantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Grid de productos
  Widget _buildGrid(List<Map<String, dynamic>> productos) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.55, // 🔥 Igual que MenuPage
      ),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final item = productos[index];

        return Card(
          elevation: 5,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagen UNIFORME
              Expanded(
                flex: 5,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    item['image'],
                    fit: BoxFit.cover, // 🔥 Igual que MenuPage
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 40),
                    ),
                  ),
                ),
              ),

              // Información
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'S/ ${item['price'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Spacer(),

                      // Botón
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text("Agregar"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink.shade600,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final cart =
                                Provider.of<Cart>(context, listen: false);
                            cart.addToCart(item);

                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.black87,
                                  content: Text(
                                    '${item['name']} agregado ✅',
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                                  duration:
                                      const Duration(milliseconds: 900),
                                ),
                              );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
