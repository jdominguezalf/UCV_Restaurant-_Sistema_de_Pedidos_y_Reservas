import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;



class AdminPedidosPage extends StatefulWidget {
  const AdminPedidosPage({super.key});

  @override
  State<AdminPedidosPage> createState() => _AdminPedidosPageState();
}

class _AdminPedidosPageState extends State<AdminPedidosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Sin fecha";
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.redAccent;
      case 'en_preparacion':
        return Colors.orangeAccent;
      case 'por_servir':
        return Colors.blueAccent;
      case 'servido':
        return Colors.green;
      case 'cancelado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Icons.access_time;
      case 'en_preparacion':
        return Icons.restaurant_menu;
      case 'por_servir':
        return Icons.fastfood;
      case 'servido':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // ---------------- EXPORTAR PDF -----------------
  Future<void> _exportarVentas(String tipo) async {
    final now = DateTime.now();
    final inicio = tipo == "día"
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month);
    final fin = tipo == "día"
        ? inicio.add(const Duration(days: 1))
        : DateTime(now.year, now.month + 1);

    final query = await FirebaseFirestore.instance
        .collection("pedidos")
        .where("creadoEn", isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where("creadoEn", isLessThan: Timestamp.fromDate(fin))
        .get();

    final pedidos = query.docs;
    if (pedidos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No hay ventas registradas en este $tipo")),
      );
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                "Reporte de Ventas del $tipo",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            ...pedidos.map((p) {
              final data = p.data() as Map<String, dynamic>;
              final cliente = data["cliente"]?["nombre"] ?? "Cliente desconocido";
              final total = (data["total"] ?? 0).toDouble();
              final estado = data["estado"] ?? "";
              final fecha = _formatDate(data["creadoEn"]);
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Cliente: $cliente",
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Estado: $estado",
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Fecha: $fecha",
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Total: S/ ${total.toStringAsFixed(2)}",
                        style: pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              );
            }).toList()
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  void _mostrarDialogoExportacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Exportar Ventas"),
        content: const Text("¿Deseas exportar las ventas del día o del mes?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportarVentas("día");
            },
            child: const Text("Del Día"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () {
              Navigator.pop(context);
              _exportarVentas("mes");
            },
            child: const Text("Del Mes"),
          ),
        ],
      ),
    );
  }

  // ---------------- SECCIÓN REPORTES -----------------
  Widget _buildReportesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("pedidos").snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple));
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar los reportes"));
        }

        final pedidos = snapshot.data?.docs ?? [];
        int totalPedidos = pedidos.length;
        int servidos = 0;
        int pendientes = 0;
        int cancelados = 0;
        double totalRecaudado = 0.0;

        for (var doc in pedidos) {
          final data = doc.data() as Map<String, dynamic>;
          switch (data["estado"]) {
            case "servido":
              servidos++;
              totalRecaudado += (data["total"] ?? 0).toDouble();
              break;
            case "pendiente":
              pendientes++;
              break;
            case "cancelado":
              cancelados++;
              break;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const SizedBox(height: 10),
              Text(
                "📊 Reportes Generales",
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildReportCard(Icons.list_alt, "Total Pedidos",
                      totalPedidos.toString(), Colors.deepPurple),
                  _buildReportCard(Icons.check_circle, "Servidos",
                      servidos.toString(), Colors.green),
                  _buildReportCard(Icons.timer, "Pendientes",
                      pendientes.toString(), Colors.orange),
                  _buildReportCard(Icons.cancel, "Cancelados",
                      cancelados.toString(), Colors.grey),
                  _buildReportCard(Icons.attach_money, "Total Recaudado",
                      "S/ ${totalRecaudado.toStringAsFixed(2)}", Colors.blue),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportCard(
      IconData icon, String title, String value, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 24,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color),
          ),
        ],
      ),
    );
  }

  // ---------------- SECCIÓN PEDIDOS -----------------
  Widget _buildPedidosSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("pedidos")
          .orderBy("creadoEn", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple));
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar los pedidos"));
        }

        final pedidos = snapshot.data?.docs ?? [];
        if (pedidos.isEmpty) {
          return const Center(
            child: Text(
              "No hay pedidos registrados aún 🍽️",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pedidos.length,
          itemBuilder: (context, index) {
            final pedido = pedidos[index];
            final data = pedido.data() as Map<String, dynamic>;
            final cliente = data["cliente"] ?? {};
            final items = List<Map<String, dynamic>>.from(data["items"] ?? []);
            final total = (data["total"] ?? 0).toDouble();
            final metodoPago = data["metodoPago"] ?? "Desconocido";
            final estado = data["estado"] ?? "pendiente";
            final mesa = data["mesa"]?.toString() ?? "N/A";
            final fecha = _formatDate(data["creadoEn"]);

            return Card(
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: _getEstadoColor(estado),
                  child:
                      Icon(_getEstadoIcon(estado), color: Colors.white, size: 26),
                ),
                title: Text(cliente["nombre"] ?? "Cliente desconocido",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text("Mesa: $mesa • $fecha",
                    style: const TextStyle(fontSize: 13)),
                trailing: Chip(
                  backgroundColor: _getEstadoColor(estado),
                  label: Text(estado.toUpperCase(),
                      style: const TextStyle(color: Colors.white)),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius:
                          const BorderRadius.vertical(bottom: Radius.circular(18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("🧾 Detalles del Pedido",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 10),
                        ...items.map((item) {
                          return ListTile(
                            leading: item["imagen"] != null &&
                                    (item["imagen"] as String).isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item["imagen"],
                                      width: 45,
                                      height: 45,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.image_not_supported,
                                    color: Colors.grey),
                            title: Text(item["nombre"] ?? ""),
                            subtitle:
                                Text("x${item["cantidad"]} unidades"),
                            trailing: Text(
                                "S/ ${(item["subtotal"] ?? 0).toStringAsFixed(2)}"),
                          );
                        }),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.payment, color: Colors.green),
                          title: Text(
                              "Total: S/ ${total.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text("Pago con: $metodoPago"),
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
  }

  // ---------------- INTERFAZ PRINCIPAL -----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("📦 Panel Administrativo"),
        centerTitle: true,
        elevation: 3,
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: "Pedidos"),
            Tab(icon: Icon(Icons.bar_chart), text: "Reportes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPedidosSection(),
          _buildReportesSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoExportacion,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Exportar"),
      ),
    );
  }
}