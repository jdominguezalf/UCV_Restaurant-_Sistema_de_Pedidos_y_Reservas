import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetalleMesaPage extends StatelessWidget {
  final int numeroMesa;
  final String estado;
  final Color color;

  const DetalleMesaPage({
    super.key,
    required this.numeroMesa,
    required this.estado,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatoHora = DateFormat('dd/MM HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("Mesa $numeroMesa - $estado"),
        backgroundColor: color,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error al cargar los pedidos 😓",
                style: TextStyle(color: Colors.red[400]),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No hay pedidos activos para esta mesa 🍽️",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          // 🔹 Filtramos por mesa y estado
          final pedidos = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final mesaData = data['mesa'];
            final estado = (data['estado'] ?? '').toLowerCase();
            final esMesa = mesaData.toString() == numeroMesa.toString();
            final activo = estado == 'pendiente' || estado == 'en preparación';
            return esMesa && activo;
          }).toList();

          if (pedidos.isEmpty) {
            return const Center(
              child: Text(
                "No hay pedidos activos para esta mesa 🍽️",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          // 🔹 Ordenamos localmente por fecha (más reciente primero)
          pedidos.sort((a, b) {
            final tA = (a['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0);
            final tB = (b['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0);
            return tB.compareTo(tA);
          });

          // 🔹 Tomamos el más reciente
          final pedido = pedidos.first;
          final data = pedido.data() as Map<String, dynamic>;

          final cliente = data['cliente']?['nombre'] ?? "Cliente";
          final fecha = (data['creadoEn'] as Timestamp?)?.toDate();
          final total = (data['total'] ?? 0).toDouble();

          final items = List<Map<String, dynamic>>.from(data['items'] ?? [])
              .where((item) =>
                  (item['estado'] ?? 'pendiente').toLowerCase() != 'servido')
              .toList();

          if (items.isEmpty) {
            return const Center(
              child: Text(
                "Todos los productos fueron servidos ✅",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🧾 Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "PEDIDO",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          fecha != null ? formatoHora.format(fecha) : '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "👤 $cliente",
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),

                    // 🍔 Grid de productos
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.00,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final imageUrl = item['imagen'] ?? "";
                        final nombre = item['nombre'] ?? "Producto";
                        final cantidad = item['cantidad'] ?? 0;
                        final subtotal = (item['subtotal'] ?? 0).toDouble();

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.fastfood,
                                          color: Colors.orangeAccent,
                                          size: 40,
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  nombre,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  "x$cantidad",
                                  style:
                                      const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "S/. ${subtotal.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "Total: S/. ${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}