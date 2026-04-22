import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../cart.dart';
import '../services/product_service.dart';
import '../widgets/check_page.dart';

class ProductosBusquedaPage extends StatelessWidget {
  final String searchTerm;
  final ProductService _productService = ProductService();

  ProductosBusquedaPage({super.key, required this.searchTerm});

  Color obtenerColorCategoria(String categoria) {
    switch (categoria.trim().toLowerCase()) {
      case 'menu':
        return Colors.orange.shade600;
      case 'bebidas':
        return Colors.pink.shade600;
      case 'poestres':
      case 'postres':
        return Colors.blue.shade600;
      case 'entradas':
      case 'entradas de menu':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados de búsqueda'),
        backgroundColor: const Color.fromARGB(255, 44, 196, 235),
        actions: [
          Consumer<Cart>(
            builder:
                (context, cart, _) => Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      onPressed: () => _mostrarCarrito(context),
                    ),
                    if (cart.totalQuantity > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.totalQuantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _productService.getAllProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay productos disponibles'));
          }

          final productosFiltrados =
              snapshot.data!
                  .where(
                    (item) => item['name'].toString().toLowerCase().contains(
                      searchTerm.toLowerCase(),
                    ),
                  )
                  .toList();

          if (productosFiltrados.isEmpty) {
            return const Center(child: Text('No se encontraron coincidencias'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.59,
            ),
            itemCount: productosFiltrados.length,
            itemBuilder: (context, index) {
              final item = productosFiltrados[index];
              final categoriaColor = obtenerColorCategoria(item['category']);

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.1,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Image.network(
                          item['image'],
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'S/ ${item['price'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: categoriaColor,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 18,
                              ),
                              label: const Text('Agregar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: categoriaColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                final cart = Provider.of<Cart>(
                                  context,
                                  listen: false,
                                );
                                cart.addToCart(item);

                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${item['name']} agregado al carrito',
                                      ),
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                    ),
                                  );
                              },
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
        },
      ),
    );
  }

  void _mostrarCarrito(BuildContext context) {
    final cart = Provider.of<Cart>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Carrito de compras'),
            content: Consumer<Cart>(
              builder: (context, cart, _) {
                if (cart.items.isEmpty) {
                  return const Text('Tu carrito está vacío');
                }

                return SizedBox(
                  height: 320,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final quantity = item['quantity'];
                      final price = item['price'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['image'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('S/ $price x $quantity'),
                                  Text(
                                    'Total: S/ ${(price * quantity).toStringAsFixed(2)}',
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: () {
                                          cart.removeFromCart(item);
                                          if (cart.items.isEmpty) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      ),
                                      Text('$quantity'),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: () => cart.addToCart(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          cart.removeCompleteItem(item['name']);
                                          if (cart.items.isEmpty) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            actions: [
              Consumer<Cart>(
                builder:
                    (context, cart, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Total: S/ ${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              ),
              TextButton(
                onPressed: () => cart.clear(),
                child: const Text('Vaciar carrito'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Seguir comprando'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CheckoutPage()),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'Pagar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}