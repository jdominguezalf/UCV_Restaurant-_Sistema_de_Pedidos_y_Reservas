import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class VentasPorProductoPage extends StatefulWidget {
  const VentasPorProductoPage({Key? key}) : super(key: key);

  @override
  State<VentasPorProductoPage> createState() => _VentasPorProductoPageState();
}

class _VentasPorProductoPageState extends State<VentasPorProductoPage> {
  late Future<List<Map<String, dynamic>>> _ventasFuture;

  @override
  void initState() {
    super.initState();
    _ventasFuture = _obtenerVentasAgrupadas();
  }

  /// 🔹 Lee los pedidos y agrupa las ventas por producto
  Future<List<Map<String, dynamic>>> _obtenerVentasAgrupadas() async {
    final snapshot = await FirebaseFirestore.instance.collection('pedidos').get();
    final Map<String, dynamic> agrupadas = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final items = (data['items'] ?? []) as List<dynamic>;

      for (var item in items) {
        final nombre = item['nombre'] ?? 'Sin nombre';

        // Conversión segura a número
        final cantidad = _toDouble(item['cantidad']);
        final precio = _toDouble(item['precio']);
        final subtotal = item['subtotal'] != null
            ? _toDouble(item['subtotal'])
            : precio * cantidad;

        if (agrupadas.containsKey(nombre)) {
          agrupadas[nombre]['cantidad'] += cantidad;
          agrupadas[nombre]['total'] += subtotal;
        } else {
          agrupadas[nombre] = {
            'cantidad': cantidad,
            'total': subtotal,
          };
        }
      }
    }

    return agrupadas.entries
        .map((e) => {
              'nombre': e.key,
              'cantidad': e.value['cantidad'],
              'total': e.value['total']
            })
        .toList();
  }

  /// 🔸 Convierte cualquier tipo a double (maneja null o String)
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas por Producto'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ventasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay registros de ventas.'));
          }

          final ventas = snapshot.data!;
          final totalProductos = ventas.length;
          final totalUnidades = ventas.fold<double>(
            0,
            (sum, v) => sum + _toDouble(v['cantidad']),
          );
          final totalRecaudado = ventas.fold<double>(
            0,
            (sum, v) => sum + _toDouble(v['total']),
          );

          final masVendido = ventas.reduce((a, b) =>
              _toDouble(a['cantidad']) > _toDouble(b['cantidad']) ? a : b);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Tarjetas resumen ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Productos vendidos', '$totalProductos'),
                    _buildStatCard('Unidades totales', '$totalUnidades'),
                    _buildStatCard('Total recaudado',
                        'S/ ${totalRecaudado.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildStatCard('Más vendido', masVendido['nombre']),

                const SizedBox(height: 30),

                // --- Gráfico de barras ---
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (ventas
                                  .map<double>(
                                      (v) => _toDouble(v['cantidad']))
                                  .reduce((a, b) => a > b ? a : b)) +
                              2,
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: true)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 && i < ventas.length) {
                                return Transform.rotate(
                                  angle: -0.8,
                                  child: Text(
                                    ventas[i]['nombre'],
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: ventas.asMap().entries.map((entry) {
                        final index = entry.key;
                        final v = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: _toDouble(v['cantidad']),
                              width: 18,
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.teal,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- Tabla de ventas ---
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.teal.shade50),
                    columns: const [
                      DataColumn(label: Text('Producto')),
                      DataColumn(label: Text('Cantidad')),
                      DataColumn(label: Text('Total (S/)')),
                    ],
                    rows: ventas
                        .map(
                          (v) => DataRow(cells: [
                            DataCell(Text(v['nombre'])),
                            DataCell(Text(v['cantidad'].toString())),
                            DataCell(Text(
                                'S/ ${_toDouble(v['total']).toStringAsFixed(2)}')),
                          ]),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 120,
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.teal,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}