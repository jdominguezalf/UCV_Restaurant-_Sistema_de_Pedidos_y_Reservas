import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../cart.dart' show cartProvider;
import '../../providers/selected_table.dart';

// ===================================================================
// 🔒 FUNCIÓN GLOBAL DE LOGOUT
// ===================================================================
Future<void> logoutUser(WidgetRef ref, BuildContext context) async {
  try {
    ref.read(cartProvider).clear();
    context.read<SelectedTable>().clearTable();

    final googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.disconnect();
    }

    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  } catch (e) {
    debugPrint("❌ Error al cerrar sesión: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cerrar sesión: $e")),
      );
    }
  }
}

// ===================================================================
// 🚪 BOTÓN DE LOGOUT
// ===================================================================
class LogoutButton extends ConsumerWidget {
  final Color iconColor;
  const LogoutButton({super.key, this.iconColor = Colors.white});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Seguro que deseas salir?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Cerrar sesión"),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await logoutUser(ref, context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.logout, color: iconColor),
      tooltip: "Cerrar sesión",
      onPressed: () => _confirmLogout(context, ref),
    );
  }
}

// ===================================================================
// 🍽️ PÁGINA DEL MESERO
// ===================================================================
class MeseroPage extends ConsumerWidget {
  const MeseroPage({super.key});

  Future<String> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "mesero"; // por defecto
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();
    return (doc.data()?['rol'] ?? 'mesero') as String;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<String>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rol = snapshot.data!;
        final isAdmin = rol == "admin";

        return Scaffold(
          appBar: AppBar(
            title: Text(isAdmin ? "Panel del Administrador" : "Panel del Mesero"),
            backgroundColor: Colors.orange.shade700,
            centerTitle: true,
            actions: const [LogoutButton()],
          ),
          drawer: isAdmin
              ? _buildAdminDrawer(context, ref, user)
              : _buildMeseroDrawer(context, ref, user),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("pedidos")
                .orderBy("creadoEn", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pedidos = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final estado = data["estado"] ?? "";
                return estado != "finalizado";
              }).toList();

              if (pedidos.isEmpty) {
                return const Center(child: Text("No hay pedidos activos 🧾"));
              }

              return ListView.builder(
                itemCount: pedidos.length,
                itemBuilder: (context, index) {
                  final pedido = pedidos[index];
                  final data = pedido.data() as Map<String, dynamic>;

                  final cliente = data["cliente"]?["nombre"] ?? "Cliente";
                  final mesa = data["mesa"] ?? "-";
                  final total = (data["total"] ?? 0.0).toDouble();
                  final estado = data["estado"] ?? "pendiente";
                  final items = (data["items"] as List<dynamic>? ?? []);

                  return Card(
                    margin: const EdgeInsets.all(12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        "Mesa $mesa - $cliente",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Total: S/ ${total.toStringAsFixed(2)}"),
                      trailing: _estadoChip(estado),
                      children: [
                        ...items.map((item) {
                          final nombre = item["nombre"] ?? "";
                          final cantidad = (item["cantidad"] ?? 0).toInt();
                          final precio =
                              (item["precioUnitario"] ?? 0.0).toDouble();
                          final subtotal = cantidad * precio;

                          return ListTile(
                            leading: item["imagen"] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item["imagen"],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.fastfood,
                                    color: Colors.orange),
                            title: Text(nombre),
                            subtitle: Text("x$cantidad"),
                            trailing:
                                Text("S/ ${subtotal.toStringAsFixed(2)}"),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (estado == "en_preparacion")
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await _updateEstado(pedido.id,
                                        mesa.toString(), "por_servir");
                                  },
                                  child: const Text("Por servir"),
                                ),
                              if (estado == "por_servir")
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await _updateEstado(pedido.id,
                                        mesa.toString(), "servido");
                                  },
                                  child: const Text("Marcar servido"),
                                ),
                              if (estado == "servido")
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await _liberarMesa(
                                        mesa.toString(), pedido.id);
                                  },
                                  child: const Text("Liberar mesa"),
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
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // 🔹 Actualizar estado del pedido + mesa sincronizada
  // ---------------------------------------------------------------
  Future<void> _updateEstado(
      String pedidoId, String mesaId, String nuevoEstado) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection("pedidos").doc(pedidoId).update({
        "estado": nuevoEstado,
        "actualizadoEn": FieldValue.serverTimestamp(),
      });

      await firestore
          .collection("mesas")
          .doc(mesaId)
          .update({"estado": nuevoEstado});

      debugPrint("✅ Pedido y mesa actualizados a $nuevoEstado");
    } catch (e) {
      debugPrint("❌ Error al actualizar estado: $e");
    }
  }

  // ---------------------------------------------------------------
  // 🔹 Liberar mesa manualmente
  // ---------------------------------------------------------------
  Future<void> _liberarMesa(String mesaId, String pedidoId) async {
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection("mesas").doc(mesaId).update({
        "estado": "libre",
      });

      await firestore.collection("pedidos").doc(pedidoId).update({
        "estado": "finalizado",
        "actualizadoEn": FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Mesa $mesaId liberada y pedido archivado");
    } catch (e) {
      debugPrint("❌ Error al liberar mesa: $e");
    }
  }

  // ---------------------------------------------------------------
  // 🎨 Chip visual de estado
  // ---------------------------------------------------------------
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
        color = Colors.blue;
        texto = "Por servir";
        break;
      case "servido":
        color = Colors.green;
        texto = "Servido";
        break;
      case "finalizado":
        color = Colors.grey;
        texto = "Finalizado";
        break;
      default:
        color = Colors.grey;
        texto = estado;
    }

    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        texto,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ---------------------------------------------------------------
  // 🔸 Drawer para MESERO
  // ---------------------------------------------------------------
  Drawer _buildMeseroDrawer(BuildContext context, WidgetRef ref, User? user) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.displayName ?? "Mesero"),
              accountEmail: Text(user?.email ?? ""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.restaurant, color: Colors.orange),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.orange.shade100],
                ),
              ),
            ),

            ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Registrar Pedido'),
            onTap: () => Navigator.pushNamed(context, '/select-table'),
          ),
          ListTile(
  leading: const Icon(Icons.table_restaurant, color: Colors.orange),
  title: const Text('Vista General Mesas'),
  onTap: () {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/vista-mesas-detalle');
  },
),

            const Spacer(),
            
            ListTile(
              
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Cerrar sesión"),
              onTap: () async {
                Navigator.pop(context);
                await logoutUser(ref, context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // 🔸 Drawer para ADMIN
  // ---------------------------------------------------------------
  Drawer _buildAdminDrawer(BuildContext context, WidgetRef ref, User? user) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'Administrador'),
            accountEmail: Text(user?.email ?? 'admin@correo.com'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, color: Colors.orange),
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
            leading: const Icon(Icons.inventory_2),
            title: const Text('Gestión de productos'),
            onTap: () => Navigator.pushNamed(context, '/admin_productos'),
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
            leading: const Icon(Icons.receipt_long),
            title: const Text('Pedidos'),
            onTap: () => Navigator.pushNamed(context, '/admin_pedidos'),
          ),
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
            title: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await logoutUser(ref, context);
            },
          ),
        ],
      ),
    );
  }
}