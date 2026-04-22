import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_options.dart';
import 'widgets/version_banner_wrapper.dart';

// --- Carrito y mesa ---
import 'cart.dart';
import 'providers/selected_table.dart';

// --- Páginas ---
import 'pages/admin/admin_dashboard.dart';
import 'pages/admin/admin_productos.dart';
import 'pages/admin/admin_pedidos.dart';
import 'pages/rol/pedidos_cocina.dart';
import 'pages/cart_page.dart';
import 'pages/select_table_page.dart';
import 'pages/menu_page.dart';
import 'pages/Bebidas_page.dart';
import 'pages/Postres_page.dart';
import 'pages/Entradas_page.dart';
import 'pages/productos_busqueda_page.dart';
import 'pages/vista_mesas/vista_general_mesas.dart';
import 'pages/vista_mesas/detalle_mesa_page.dart';
import 'pages/pantalla_bienvenida.dart';
import 'pages/pantalla_finaliza.dart';
import 'pages/pantalla_login.dart';
import 'pages/pantalla_registro.dart';
import 'pages/ventas/ventas_por_producto.dart';
import 'pages/rol/mesero_page.dart';

// ===============================
//  MAIN
// ===============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => Cart()),
          provider.ChangeNotifierProvider(create: (_) => SelectedTable()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

// ===============================
//  Helper para CERRAR SESIÓN
// ===============================
Future<void> cerrarSesionSeguro(BuildContext context) async {
  try {
    // Siempre cerramos Firebase
    await FirebaseAuth.instance.signOut();

    // Solo cerramos Google en Android/iOS
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }
}

// ===============================
//  MyApp
// ===============================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.deepOrange;

    return MaterialApp(
      title: 'UCV Restaurant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: baseColor),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),

      // ====== WRAPPER RESPONSIVE PARA WEB Y MOBILE ======
     builder: (context, child) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  final isMobile = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1000;
  final isDesktop = screenWidth >= 1000;

  double maxWidth = double.infinity;
  EdgeInsets padding = EdgeInsets.zero;
  double textScale = 1.0;

  if (isMobile) {
    maxWidth = screenWidth;
    padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  } else if (isTablet) {
    maxWidth = 700;
    padding = const EdgeInsets.all(16);
  } else if (isDesktop) {
    maxWidth = 1000;
    padding = const EdgeInsets.all(5);
  }

  if (kIsWeb) {
    if (isTablet) textScale = 1.1;
    if (isDesktop) textScale = 1.22;
  }

  return Container(
    height: screenHeight,
    width: screenWidth,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.fromARGB(255, 245, 125, 20),
          Color.fromARGB(255, 231, 151, 54),
          Color.fromARGB(255, 245, 174, 123),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Center(
      child: kIsWeb
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              padding: padding,
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: Colors.transparent,
                  width: 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: textScale,
                ),
                
                child: VersionBannerWrapper(child: child!),
              ),
            )
          : VersionBannerWrapper(child: child!), 
    ),
  );
},


      initialRoute: '/Bienvenida',
      routes: {
        '/Bienvenida': (_) => const PantallaBienvenida(),
        '/home': (_) => const HomePage(),
        '/Finaliza': (_) => const PantallaFinaliza(),
        '/login': (_) => const PantallaLogin(),
        '/registro': (_) => const PantallaRegistro(),
        '/select-table': (_) => const SelectTablePage(),
        '/admin-productos': (_) => const AdminDashboardPage(),
        '/home-cliente': (_) => const HomePage(),
        '/home-mesero': (_) => const MeseroPage(),
        '/pedidos-mesero': (_) => const MeseroPage(),
        '/pedidos-cocina': (_) => const PedidosCocinaPage(),
        '/admin_dashboard': (_) => const AdminDashboardPage(),
        '/admin_productos': (_) => const AdminProductosPage(),
        '/admin_pedidos': (_) => const AdminPedidosPage(),
        '/vista-mesas-detalle': (_) => const VistaGeneralMesasPage(),
        '/ventas_por_producto': (context) => const VentasPorProductoPage(),
      },
    );
  }
}

// =======================================
// HomePage con Drawer dinámico por rol
// =======================================
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['rol'] ?? 'cliente';
        });
      }
    } catch (e) {
      debugPrint('Error obteniendo rol del usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacementNamed('/Bienvenida');
        return false;
      },
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          // --- Drawer lateral ---
          drawer: Drawer(
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade400, Colors.deepOrange.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : const AssetImage('lib/imgtaully/logo_ucv_restaurant.png')
                                  as ImageProvider,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user?.displayName ?? 'Cliente Invitado',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          user?.email ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_userRole != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              'Rol: $_userRole',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _drawerItem(
                    icon: Icons.table_restaurant,
                    text: 'Seleccionar mesa',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/select-table');
                    },
                  ),
                  _drawerItem(
                    icon: Icons.shopping_cart,
                    text: 'Carrito',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                  ),
                  if (_userRole == 'mesero' || _userRole == 'admin')
                    _drawerItem(
                      icon: Icons.dashboard,
                      text: 'Panel pedidos',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/pedidos-mesero');
                      },
                    ),
                  if (_userRole == 'admin')
                    _drawerItem(
                      icon: Icons.admin_panel_settings,
                      text: 'Panel principal',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/admin_dashboard');
                      },
                    ),
                  const Spacer(),
                  Divider(color: Colors.orange.shade200, thickness: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Cerrar sesión',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cerrar sesión'),
                          content: const Text('¿Deseas salir de tu cuenta actual?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sí, salir'),
                            ),
                          ],
                        ),
                      );

                      if (confirmar == true) {
                        await cerrarSesionSeguro(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // --- AppBar ---
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colors.white,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  'UCV Restaurant',
                  style: GoogleFonts.poppins(
                    color: Colors.deepOrange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Deseas salir de tu cuenta actual?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sí, salir'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true) {
                    await cerrarSesionSeguro(context);
                  }
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Card(
                      elevation: 2,
                      shadowColor: Colors.orange.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar en el menú...',
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.orange),
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchTerm = '';
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchTerm = value.trim().toLowerCase();
                          });
                        },
                      ),
                    ),
                  ),
                  if (_searchTerm.isEmpty)
                    TabBar(
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Colors.orange.shade600,
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black54,
                      tabs: const [
                        Tab(icon: Icon(Icons.fastfood), text: 'Menú'),
                        Tab(icon: Icon(Icons.local_drink), text: 'Bebidas'),
                        Tab(icon: Icon(Icons.cake), text: 'Postres'),
                        Tab(icon: Icon(Icons.rice_bowl), text: 'Entradas'),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // --- Cuerpo principal ---
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _searchTerm.isEmpty
                ? const TabBarView(
                    children: [
                      MenuPage(searchTerm: ''),
                      BebidasPage(searchTerm: ''),
                      PostresPage(searchTerm: ''),
                      EntradasPage(searchTerm: ''),
                    ],
                  )
                : ProductosBusquedaPage(searchTerm: _searchTerm),
          ),

          // --- Botón flotante del carrito ---
          floatingActionButton: provider.Consumer<Cart>(
            builder: (context, cart, _) {
              if (cart.totalQuantity == 0) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                backgroundColor: Colors.green.shade700,
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                label: Text(
                  '${cart.totalQuantity}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange.shade700),
      title: Text(
        text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
