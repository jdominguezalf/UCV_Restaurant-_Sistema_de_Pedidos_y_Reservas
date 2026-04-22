import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_mesa_page.dart';

class VistaGeneralMesasPage extends StatefulWidget {
  const VistaGeneralMesasPage({super.key});

  @override
  State<VistaGeneralMesasPage> createState() => _VistaGeneralMesasPageState();
}

class _VistaGeneralMesasPageState extends State<VistaGeneralMesasPage> {
  String? filtroEstado;

  static const List<String> _estadosActivos = [
    'pendiente',
    'en_preparacion',
    'por_servir'
  ];

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final crossAxisCount = ancho > 2000
        ? 5
        : ancho > 900
            ? 4
            : ancho > 600
                ? 3
                : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 6,
        backgroundColor: const Color(0xFF2E4890),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🍽️ Vista General de Mesas",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              filtroEstado != null
                  ? "Filtrando por: ${_formatearEstado(filtroEstado!)}"
                  : "Monitorea el estado y pedidos en tiempo real",
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: "Actualizar",
            onPressed: () {
              setState(() => filtroEstado = null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Vista actualizada"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            tooltip: "Filtrar",
            onPressed: _mostrarFiltroSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mesas')
            .orderBy('numero')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las mesas 😔'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final mesas = snapshot.data!.docs.where((mesaDoc) {
            final mesa = mesaDoc.data() as Map<String, dynamic>;
            final estado = mesa['estado'] ?? 'libre';
            if (filtroEstado == null) return true;
            return estado == filtroEstado;
          }).toList();

          if (mesas.isEmpty) {
            return const Center(
              child: Text(
                'No hay mesas con este estado 🪑',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 0.82,
            ),
            itemCount: mesas.length,
            itemBuilder: (context, index) {
              final mesaDoc = mesas[index];
              final mesa = mesaDoc.data() as Map<String, dynamic>;
              final numero = mesa['numero'] ?? 0;
              final estado = (mesa['estado'] ?? 'libre').toString();
              final estilo = _getEstiloEstado(estado);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pedidos')
                    .where('mesa', isEqualTo: numero)
                    .snapshots(),
                builder: (context, pedidosSnap) {
                  int totalProductos = 0;
                  double totalMonto = 0;

                  if (pedidosSnap.hasData &&
                      pedidosSnap.data!.docs.isNotEmpty) {
                    final pedidos = pedidosSnap.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return data;
                    }).where((data) {
                      final estado =
                          (data['estado'] ?? '').toString().toLowerCase();
                      return _estadosActivos.contains(estado);
                    }).toList();

                    if (pedidos.isNotEmpty) {
                      final items = (pedidos.first['items'] as List?)
                              ?.cast<Map<String, dynamic>>() ??
                          [];
                      for (var item in items) {
                        totalProductos += (item['cantidad'] ?? 0) as int;
                        totalMonto +=
                            double.tryParse(item['subtotal'].toString()) ?? 0.0;
                      }
                    }
                  }

                  return AnimatedScale(
                    scale: 1,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTapDown: (_) =>
                          setState(() => _animarMesa = numero), // efecto tap
                      onTapUp: (_) => setState(() => _animarMesa = null),
                      onTapCancel: () => setState(() => _animarMesa = null),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetalleMesaPage(
                              numeroMesa: numero,
                              estado: estilo['texto']!,
                              color: estilo['color'] as Color,
                            ),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: estilo['gradiente'] as List<Color>,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (estilo['color'] as Color).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _mesaCard(
                          numero: numero,
                          textoEstado: estilo['texto']!,
                          color: estilo['color'] as Color,
                          icon: estilo['icon'] as IconData,
                          totalProductos: totalProductos,
                          totalMonto: totalMonto,
                        ),
                      ),
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

  int? _animarMesa;

  /// 🧭 Modal de filtro moderno
  void _mostrarFiltroSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Filtrar por estado",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _chipFiltro("libre", Colors.green),
                  _chipFiltro("pendiente", Colors.redAccent),
                  _chipFiltro("en_preparacion", Colors.orangeAccent),
                  _chipFiltro("por_servir", Colors.purpleAccent),
                  _chipFiltro("servido", Colors.blueAccent),
                ],
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  setState(() => filtroEstado = null);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text("Quitar filtro"),
              )
            ],
          ),
        );
      },
    );
  }

  /// 🎨 Botón de filtro tipo chip
  Widget _chipFiltro(String estado, Color color) {
    final seleccionado = filtroEstado == estado;
    return ChoiceChip(
      label: Text(_formatearEstado(estado)),
      selected: seleccionado,
      selectedColor: color.withOpacity(0.8),
      backgroundColor: color.withOpacity(0.2),
      labelStyle:
          TextStyle(color: seleccionado ? Colors.white : Colors.black87),
      onSelected: (_) {
        setState(() => filtroEstado = estado);
        Navigator.pop(context);
      },
    );
  }

  /// 🧾 Tarjeta de mesa visual moderna
  Widget _mesaCard({
    required int numero,
    required String textoEstado,
    required Color color,
    required IconData icon,
    required int totalProductos,
    required double totalMonto,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.25),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            "Mesa $numero",
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            textoEstado,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Divider(
            color: Colors.white54,
            height: 16,
            thickness: 0.8,
            indent: 30,
            endIndent: 30,
          ),
          Text(
            "🧾 $totalProductos productos",
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            "💰 S/. ${totalMonto.toStringAsFixed(2)}",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Configuración de estilos por estado
  Map<String, dynamic> _getEstiloEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return {
          'color': Colors.redAccent,
          'icon': Icons.access_time,
          'texto': 'Pendiente',
          'gradiente': [Colors.redAccent, Colors.red.shade300]
        };
      case 'en_preparacion':
        return {
          'color': Colors.orangeAccent,
          'icon': Icons.restaurant,
          'texto': 'En preparación',
          'gradiente': [Colors.orangeAccent, Colors.deepOrange.shade200]
        };
      case 'por_servir':
        return {
          'color': Colors.purpleAccent,
          'icon': Icons.delivery_dining,
          'texto': 'Por servir',
          'gradiente': [Colors.purpleAccent, Colors.deepPurple.shade300]
        };
      case 'servido':
        return {
          'color': Colors.blueAccent,
          'icon': Icons.check_circle,
          'texto': 'Servido',
          'gradiente': [Colors.blueAccent, Colors.lightBlueAccent]
        };
      default:
        return {
          'color': Colors.green,
          'icon': Icons.event_seat,
          'texto': 'Libre',
          'gradiente': [
            Colors.greenAccent.shade400,
            Colors.greenAccent.shade100
          ]
        };
    }
  }

  String _formatearEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'en_preparacion':
        return 'En preparación';
      case 'por_servir':
        return 'Por servir';
      case 'servido':
        return 'Servido';
      default:
        return 'Libre';
    }
  }
}

