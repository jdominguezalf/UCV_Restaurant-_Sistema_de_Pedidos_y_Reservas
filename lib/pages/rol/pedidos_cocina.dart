import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class PedidosCocinaPage extends StatefulWidget {
  const PedidosCocinaPage({super.key});

  @override
  State<PedidosCocinaPage> createState() => _PedidosCocinaPageState();
}

class _PedidosCocinaPageState extends State<PedidosCocinaPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  String? _nombreAdmin;
  String? _rol;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final doc = await _firestore.collection('usuarios').doc(user?.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nombreAdmin = data['nombre'] ?? 'Administrador';
          _rol = data['rol'] ?? 'mesero';
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error al cargar datos del usuario: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pedidos de Cocina"),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection("pedidos")
      .orderBy("creadoEn", descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Center(
        child: Text("🍳 No hay pedidos registrados aún",
            style: TextStyle(fontSize: 18)),
      );
    }

    final pedidos = snapshot.data!.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final estado = data["estado"] ?? "";
      return estado == "pendiente" || estado == "en_preparacion";
    }).toList();

    if (pedidos.isEmpty) {
      return const Center(
        child: Text("🍽 No hay pedidos activos", style: TextStyle(fontSize: 18)),
      );
    }

 // 🔹 Vista tipo GRID adaptable (1 o 2 columnas)
return LayoutBuilder(
  builder: (context, constraints) {
    final crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.25,
      ),
      itemCount: pedidos.length,
      itemBuilder: (context, index) {
        final pedido = pedidos[index];
        final data = pedido.data() as Map<String, dynamic>;

        final cliente = data["cliente"]?["nombre"] ?? "Cliente";
        final mesa = data["mesa"] ?? "-";
        final total = (data["total"] ?? 0).toDouble();
        final estado = data["estado"] ?? "pendiente";
        final items = (data["items"] as List<dynamic>? ?? []);

        // 🔸 Colores según estado
        Color headerColor;
        if (estado == "pendiente") {
          headerColor = Colors.redAccent.shade100;
        } else if (estado == "en_preparacion") {
          headerColor = Colors.orangeAccent.shade100;
        } else {
          headerColor = Colors.greenAccent.shade100;
        }

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔸 Encabezado visual del pedido
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mesa $mesa",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _estadoChip(estado),
                  ],
                ),
              ),

              // 🔸 Contenido del pedido con imágenes
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final name = item["nombre"] ?? "Producto";
                      final quantity = (item["cantidad"] ?? 0).toInt();
                      final imageUrl = item["imagen"] ?? "";

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.shade300, width: 0.6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 🔹 Imagen del producto
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 55,
                                      height: 55,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.fastfood,
                                                  size: 40,
                                                  color: Colors.brown),
                                    )
                                  : const Icon(Icons.fastfood,
                                      size: 40, color: Colors.brown),
                            ),
                            const SizedBox(width: 10),

                            // 🔹 Nombre y cantidad
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "Cantidad: $quantity",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const Divider(height: 10),

              // 🔸 Total y botones
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total: S/ ${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        if (estado == "pendiente")
                          ElevatedButton(
                            onPressed: () =>
                                _updateEstado(pedido.id, "en_preparacion"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text("Preparar"),
                          ),
                        if (estado == "en_preparacion")
                          ElevatedButton(
                            onPressed: () =>
                                _updateEstado(pedido.id, "por_servir"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text("Listo"),
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
    );
  },
);

  },
),

    );
  }

  // 🔹 Actualiza el estado del pedido y la mesa
  Future<void> _updateEstado(String pedidoId, String nuevoEstado) async {
    try {
      final pedidoRef = _firestore.collection("pedidos").doc(pedidoId);
      final pedidoSnap = await pedidoRef.get();

      if (!pedidoSnap.exists) throw Exception("Pedido no encontrado");

      final data = pedidoSnap.data() as Map<String, dynamic>?;
      final mesaId = data?["mesa"]?.toString();

      await pedidoRef.update({
        "estado": nuevoEstado,
        "actualizadoEn": FieldValue.serverTimestamp(),
      });

      if (mesaId != null && mesaId.isNotEmpty) {
        String nuevoEstadoMesa;
        switch (nuevoEstado) {
          case "pendiente":
            nuevoEstadoMesa = "pendiente";
            break;
          case "en_preparacion":
            nuevoEstadoMesa = "en_preparacion";
            break;
          case "por_servir":
            nuevoEstadoMesa = "por_servir";
            break;
          default:
            nuevoEstadoMesa = "libre";
        }

        await _firestore
            .collection("mesas")
            .doc(mesaId)
            .update({"estado": nuevoEstadoMesa});
      }
    } catch (e) {
      debugPrint("❌ Error al actualizar estado: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar estado: $e")),
        );
      }
    }
  }

  Widget _estadoChip(String estado) {
    Color color;
    String texto;

    switch (estado) {
      case "pendiente":
        color = Colors.red;
        texto = "Pendiente";
        break;
      case "en_preparacion":
        color = Colors.orange;
        texto = "En preparación";
        break;
      case "por_servir":
        color = Colors.green;
        texto = "Por servir";
        break;
      default:
        color = Colors.grey;
        texto = estado;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.2),
      label: Text(
        texto,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 🔸 Drawer con roles dinámicos
  Widget _buildDrawer() {
    // Si aún no se cargó el rol
    if (_rol == null) {
      return const Drawer(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔸 Si es admin → Drawer completo
    if (_rol == 'admin') {
      return Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                _nombreAdmin ?? 'Administrador',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: const Text('Rol: Admin'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('lib/imgtaully/logo_ucv_restaurant.png'),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepOrange, Colors.orangeAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Panel principal'),
              onTap: () => Navigator.pushNamed(context, '/admin_dashboard'),
            ),
             ListTile(
          leading: const Icon(Icons.table_restaurant, color: Colors.orange),
          title: const Text('Vista General Mesas'),
          onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/vista-mesas-detalle');
              },
          ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Gestión de productos'),
              onTap: () => Navigator.pushNamed(context, '/admin_productos'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Pedidos'),
              onTap: () => Navigator.pushNamed(context, '/admin_pedidos'),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text('Ventas por Producto'),
              onTap: () => Navigator.pushNamed(context, '/ventas_por_producto'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Vista del Mesero'),
              onTap: () => Navigator.pushNamed(context, '/pedidos-mesero'),
            ),
            ListTile(
              leading: const Icon(Icons.kitchen),
              title: const Text('Vista de Cocina'),
              onTap: () => Navigator.pushNamed(context, '/pedidos-cocina'),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      );
    }

    // 🔸 Si no es admin → Drawer simple
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? "Usuario"),
              accountEmail: Text("Rol: ${_rol ?? 'cocina'}"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.orange),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.deepOrange],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.kitchen),
              title: const Text("Pedidos Cocina"),
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Cerrar sesión"),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) await googleSignIn.disconnect();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil("/login", (r) => false);
      }
    } catch (e) {
      debugPrint("❌ Error al cerrar sesión: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cerrar sesión: $e")),
        );
      }
    }
  }
}