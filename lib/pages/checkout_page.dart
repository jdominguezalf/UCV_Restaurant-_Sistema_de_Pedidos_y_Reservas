import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../cart.dart';
import '../providers/selected_table.dart';
import '../services/payment_service.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _paymentMethod = "efectivo";
  final _paymentService = PaymentService();
  String? _rolUsuario;
  final TextEditingController _nombreClienteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  /// 🔹 Obtiene el rol del usuario logueado
  Future<void> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    setState(() {
      _rolUsuario = doc.data()?['rol'] ?? 'cliente';
    });
  }

  /// 🔹 Confirmar pedido y guardar en Firestore
  Future<void> _confirmOrder(BuildContext context) async {
    final cart = context.read<Cart>();
    final mesaSeleccionada = context.read<SelectedTable>().mesaSeleccionada;
    final user = FirebaseAuth.instance.currentUser;

    if (mesaSeleccionada == null || cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faltan datos para confirmar el pedido")),
      );
      return;
    }

    // ✅ Rol admin o mesero debe ingresar nombre manual
    final clienteNombre = (_rolUsuario == "mesero" || _rolUsuario == "admin")
        ? _nombreClienteController.text.trim()
        : (user?.displayName ?? "Cliente");

    if ((_rolUsuario == "mesero" || _rolUsuario == "admin") && clienteNombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor ingresa el nombre del cliente")),
      );
      return;
    }

    // 🕓 Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text("Procesando pedido..."),
        content: SizedBox(
          height: 70,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    // Simular pago
    final success = await _paymentService.processPayment(
      method: _paymentMethod,
      amount: cart.totalAmount,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // cerrar diálogo

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El pago no se pudo procesar")),
      );
      return;
    }

    try {
      // ✅ Guardar pedido en Firestore
      await FirebaseFirestore.instance.collection("pedidos").add({
        "cliente": {
          "id": user?.uid ?? "sin_id",
          "nombre": clienteNombre,
          "email": user?.email ?? "",
          "registradoPor": _rolUsuario ?? "cliente",
        },
        "mesa": mesaSeleccionada,
        "items": cart.items.map((item) {
          final price = (item["price"] ?? 0).toDouble();
          final quantity = (item["quantity"] ?? 0).toInt();
          return {
            "nombre": item["name"] ?? "",
            "cantidad": quantity,
            "precioUnitario": price,
            "subtotal": price * quantity,
            "imagen": item["image"] ?? "",
          };
        }).toList(),
        "total": cart.totalAmount,
        "metodoPago": _paymentMethod,
        "estado": "pendiente",
        "creadoEn": FieldValue.serverTimestamp(),
      });

      // ✅ Actualizar estado mesa
      final mesaRef = FirebaseFirestore.instance.collection("mesas").doc(mesaSeleccionada.toString());
      final doc = await mesaRef.get();
      if (doc.exists) {
        await mesaRef.update({"estado": "pendiente"});
      }

      // ✅ Limpiar carrito
      cart.clear();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, "/Finaliza", (r) => false);
    } catch (e, st) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar el pedido: $e")),
      );
      debugPrint("⚠️ Error al confirmar pedido: $e\n$st");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final mesa = context.watch<SelectedTable>().mesaSeleccionada;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirmar Pedido"),
        backgroundColor: Colors.deepOrange,
      ),
      body: _rolUsuario == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🔹 Datos del cliente
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.deepOrange),
                      title: (_rolUsuario == "mesero" || _rolUsuario == "admin")
                          ? TextField(
                              controller: _nombreClienteController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: "Nombre del cliente",
                                hintText: "Ej: Juan Pérez",
                                border: OutlineInputBorder(),
                              ),
                            )
                          : Text(user?.displayName ?? "Cliente"),
                      subtitle: Text(
                        (_rolUsuario == "mesero" || _rolUsuario == "admin")
                            ? "Pedido registrado manualmente"
                            : (user?.email ?? "Sin correo"),
                      ),
                      trailing: Text("Mesa $mesa"),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🛒 Lista de productos
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        final price = (item["price"] ?? 0).toDouble();
                        final quantity = (item["quantity"] ?? 0).toInt();

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: item["image"] != null &&
                                    (item["image"] as String).isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item["image"],
                                      width: 45,
                                      height: 45,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.image_not_supported, color: Colors.grey),
                            title: Text(item["name"] ?? ""),
                            subtitle: Text("x$quantity"),
                            trailing: Text(
                              "S/ ${(price * quantity).toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 💰 Total
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "Total: S/ ${cart.totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // 💳 Métodos de pago
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Método de pago:", style: TextStyle(fontWeight: FontWeight.bold)),
                      RadioListTile(
                        value: "efectivo",
                        groupValue: _paymentMethod,
                        title: const Text("Efectivo"),
                        activeColor: Colors.deepOrange,
                        onChanged: (val) => setState(() => _paymentMethod = val ?? "efectivo"),
                      ),
                      RadioListTile(
                        value: "tarjeta",
                        groupValue: _paymentMethod,
                        title: const Text("Tarjeta"),
                        activeColor: Colors.deepOrange,
                        onChanged: (val) => setState(() => _paymentMethod = val ?? "tarjeta"),
                      ),
                      RadioListTile(
                        value: "yape",
                        groupValue: _paymentMethod,
                        title: const Text("Yape / Plin"),
                        activeColor: Colors.deepOrange,
                        onChanged: (val) => setState(() => _paymentMethod = val ?? "yape"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ✅ Botón confirmar pedido
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Confirmar Pedido"),
                    onPressed: () => _confirmOrder(context),
                  ),
                ],
              ),
            ),
    );
  }
}