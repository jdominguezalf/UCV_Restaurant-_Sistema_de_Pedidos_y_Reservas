import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String? _nombreAdmin;

  @override
  void initState() {
    super.initState();
    _cargarNombreAdmin();
  }

  Future<void> _cargarNombreAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _nombreAdmin = doc['nombre'] ?? user.email;
        });
      }
    }
  }

  Future<int> _contarProductos() async {
    final snapshot = await FirebaseFirestore.instance.collection('products').get();
    return snapshot.size;
  }

  Future<int> _contarPedidos() async {
    final snapshot = await FirebaseFirestore.instance.collection('pedidos').get();
    return snapshot.size;
  }

  Future<double> _totalVentas() async {
    final snapshot = await FirebaseFirestore.instance.collection('pedidos').get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      total += (data['total'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  // --- Gráficas ---
  Future<Map<String, double>> _ventasPorProducto() async {
    final snapshot = await FirebaseFirestore.instance.collection('pedidos').get();
    Map<String, double> ventas = {};
    for (var doc in snapshot.docs) {
      final items = doc['items'] as List<dynamic>;
      for (var item in items) {
        String nombre = item['nombre'] ?? 'Producto';
        double subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;
        ventas[nombre] = (ventas[nombre] ?? 0) + subtotal;
      }
    }
    return ventas;
  }

  Future<Map<String, double>> _ventasMensuales() async {
    final snapshot = await FirebaseFirestore.instance.collection('pedidos').get();
    Map<String, double> ventas = {
      'Ene': 0, 'Feb': 0, 'Mar': 0, 'Abr': 0, 'May': 0, 'Jun': 0,
      'Jul': 0, 'Ago': 0, 'Sep': 0, 'Oct': 0, 'Nov': 0, 'Dic': 0
    };

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['fecha'] as Timestamp?;
      if (timestamp != null) {
        final fecha = timestamp.toDate();
        final mes = fecha.month;
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final nombreMes = ventas.keys.elementAt(mes - 1);
        ventas[nombreMes] = (ventas[nombreMes] ?? 0) + total;
      }
    }
    return ventas;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 26,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // 🔸 Drawer con nuevos accesos (Cocina y Mesero)
  Widget _buildDrawer() {
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
            leading: const Icon(Icons.dashboard),
            title: const Text('Registrar Pedido'),
            onTap: () => Navigator.pushNamed(context, '/select-table'),
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

          // 🔹 Acceso al módulo del Mesero
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Vista del Mesero'),
            onTap: () => Navigator.pushNamed(context, '/pedidos-mesero'),
            
          ),

          // 🔹 Acceso al módulo de la Cocina
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

  Widget _buildPieChart(Map<String, double> dataMap) {
    List<PieChartSectionData> sections = [];
    final total = dataMap.values.fold<double>(0, (a, b) => a + b);
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber
    ];
    int i = 0;
    dataMap.forEach((key, value) {
      final percentage = total == 0 ? 0 : (value / total) * 100;
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 45,
        titleStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });
    return PieChart(PieChartData(
      sections: sections,
      centerSpaceRadius: 35,
      sectionsSpace: 2,
      borderData: FlBorderData(show: false),
    ));
  }

  Widget _buildBarChart(Map<String, double> dataMap) {
    final List<BarChartGroupData> barGroups = [];
    int i = 0;
    dataMap.forEach((mes, valor) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: valor,
              color: Colors.deepOrangeAccent,
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      i++;
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (dataMap.values.fold<double>(0, (a, b) => a > b ? a : b)) * 1.2,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final meses = dataMap.keys.toList();
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    meses[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: theme.colorScheme.primary,
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FutureBuilder<int>(
                    future: _contarProductos(),
                    builder: (context, snapshot) {
                      return _buildCard(
                        icon: Icons.inventory_2,
                        title: 'Productos',
                        value: snapshot.data?.toString() ?? '0',
                        color: Colors.orange,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<int>(
                    future: _contarPedidos(),
                    builder: (context, snapshot) {
                      return _buildCard(
                        icon: Icons.receipt_long,
                        title: 'Pedidos',
                        value: snapshot.data?.toString() ?? '0',
                        color: Colors.green,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<double>(
                    future: _totalVentas(),
                    builder: (context, snapshot) {
                      return _buildCard(
                        icon: Icons.attach_money,
                        title: 'Ventas',
                        value: 'S/ ${snapshot.data?.toStringAsFixed(2) ?? '0.00'}',
                        color: Colors.blue,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text("Ventas por Producto",
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, double>>(
                      future: _ventasPorProducto(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text("No hay datos de ventas");
                        }
                        return SizedBox(height: 240, child: _buildPieChart(snapshot.data!));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text("Ventas Mensuales",
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, double>>(
                      future: _ventasMensuales(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text("No hay datos de ventas");
                        }
                        return SizedBox(height: 250, child: _buildBarChart(snapshot.data!));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}