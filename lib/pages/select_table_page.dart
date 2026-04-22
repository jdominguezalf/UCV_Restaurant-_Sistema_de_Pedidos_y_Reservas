import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/selected_table.dart';
import 'dart:math' as math;
class SelectTablePage extends StatelessWidget {
  const SelectTablePage({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedMesa = context.watch<SelectedTable>().mesaSeleccionada;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF111827),
              Color(0xFF1F2937),
              Color(0xFFE5EDFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🧭 Header tipo "hero"
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        "Selección de Mesa",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(Icons.restaurant_menu,
                        color: Colors.white, size: 26),
                  ],
                ),
              ),

              // 🧾 Información de contexto + mesa seleccionada
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "UCV Restaurant - Zona Comedor",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFCBD5F5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedMesa != null
                                ? "Actualmente estás gestionando la mesa $selectedMesa."
                                : "Elige una mesa libre para iniciar un nuevo pedido.",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_seat,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedMesa != null
                                    ? "Mesa $selectedMesa"
                                    : "Sin selección",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 📦 Tarjeta principal
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),

                        // Título interno + mini descripción
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 4),
                          child: Row(
                            children: const [
                              Icon(Icons.grid_view,
                                  size: 20, color: Color(0xFF1F2937)),
                              SizedBox(width: 8),
                              Text(
                                "Mapa interactivo de mesas",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Observa el estado de cada mesa en tiempo real.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // 📘 Leyenda
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE0E7FF),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _legendChip(Colors.green, "Libre"),
                                      _legendChip(Colors.red, "Pendiente"),
                                      _legendChip(
                                          Colors.orange, "En preparación"),
                                      _legendChip(
                                          Colors.purple, "Por servir"),
                                      _legendChip(Colors.blue, "Servido"),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 🔍 Contenido de mesas (grid)
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection("mesas")
                                .orderBy("numero")
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    "Error al cargar mesas",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                );
                              }

                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final mesas = snapshot.data!.docs;

                              if (mesas.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "No hay mesas registradas.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                );
                              }

                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  int crossAxisCount = 3;
                                  if (constraints.maxWidth > 950) {
                                    crossAxisCount = 6;
                                  } else if (constraints.maxWidth > 700) {
                                    crossAxisCount = 5;
                                  } else if (constraints.maxWidth > 520) {
                                    crossAxisCount = 4;
                                  }

                                  return GridView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: 18,
                                      crossAxisSpacing: 18,
                                      childAspectRatio: 0.9,
                                    ),
                                    itemCount: mesas.length,
                                    itemBuilder: (context, i) {
                                      final data = mesas[i].data()
                                          as Map<String, dynamic>;
                                      final numero = data['numero'] as int;
                                      final estado =
                                          data['estado'] as String? ?? 'libre';

                                      final estilo =
                                          _getEstiloEstado(estado);
                                      final isLibre = estado == 'libre';
                                      final isSelected =
                                          selectedMesa == numero;

                                      return _MesaTopViewCard(
                                        numero: numero,
                                        estilo: estilo,
                                        isLibre: isLibre,
                                        isSelected: isSelected,
                                        onTap: isLibre
                                            ? () {
                                                context
                                                    .read<SelectedTable>()
                                                    .selectMesa(numero);
                                                Navigator
                                                    .pushReplacementNamed(
                                                        context, "/home");
                                              }
                                            : null,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 Chip simple para leyenda
  static Widget _legendChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 🌈 Estilos por estado
  static Map<String, dynamic> _getEstiloEstado(String estado) {
    switch (estado) {
      case "pendiente":
        return {
          'color': Colors.red,
          'texto': "Pendiente",
          'gradiente': [Colors.red.shade400, Colors.red.shade300],
        };
      case "en_preparacion":
        return {
          'color': Colors.orange,
          'texto': "En preparación",
          'gradiente': [Colors.orange.shade400, Colors.deepOrange.shade300],
        };
      case "por_servir":
        return {
          'color': Colors.purple,
          'texto': "Por servir",
          'gradiente': [Colors.purple.shade400, Colors.deepPurple.shade300],
        };
      case "servido":
        return {
          'color': Colors.blue,
          'texto': "Servido",
          'gradiente': [Colors.blue.shade400, Colors.lightBlue.shade300],
        };
      default:
        return {
          'color': Colors.green,
          'texto': "Libre",
          'gradiente': [Colors.green.shade400, Colors.teal.shade300],
        };
    }
  }
}

/// 🎨 Tarjeta con vista superior de la mesa (mesa + sillas)
class _MesaTopViewCard extends StatelessWidget {
  final int numero;
  final Map<String, dynamic> estilo;
  final bool isLibre;
  final bool isSelected;
  final VoidCallback? onTap;

  const _MesaTopViewCard({
    required this.numero,
    required this.estilo,
    required this.isLibre,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = estilo['color'] as Color;

    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 230),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.white,
                baseColor.withOpacity(0.06),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: isSelected
                  ? Colors.amberAccent.shade400
                  : Colors.grey.shade200,
              width: isSelected ? 2.4 : 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: baseColor.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // badge estado
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (estilo['texto'] as String),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: baseColor.withOpacity(0.85),
                    ),
                  ),
                ),
              ),

              // mesa + sillas
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // mesa central
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors:
                                      List<Color>.from(estilo['gradiente']),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "$numero",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),

                            // sillas
                            _buildChair(
                                constraints: constraints,
                                angleDeg: 0,
                                color: baseColor),
                            _buildChair(
                                constraints: constraints,
                                angleDeg: 90,
                                color: baseColor),
                            _buildChair(
                                constraints: constraints,
                                angleDeg: 180,
                                color: baseColor),
                            _buildChair(
                                constraints: constraints,
                                angleDeg: 270,
                                color: baseColor),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // texto inferior
              Column(
                children: [
                  Text(
                    "Mesa $numero",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLibre ? "Disponible para asignar" : "Ocupada / en uso",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🔵 Silla usando Transform, NO Positioned
Widget _buildChair({
  required BoxConstraints constraints,
  required double angleDeg,
  required Color color,
}) {
  final double angleRad = angleDeg * math.pi / 180;
  final double radius = constraints.maxWidth * 0.32;

  final double dx = radius * math.cos(angleRad);
  final double dy = radius * math.sin(angleRad);

  return Transform.translate(
    offset: Offset(dx, dy),
    child: Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    ),
  );
}

  
