import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/product_service.dart';

class AdminProductosPage extends StatefulWidget {
  const AdminProductosPage({Key? key}) : super(key: key);

  @override
  State<AdminProductosPage> createState() => _AdminProductosPageState();
}

class _AdminProductosPageState extends State<AdminProductosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductService _productService = ProductService();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categorias = ['Menú', 'Bebidas', 'Postres', 'Entradas'];
  String _categoriaSeleccionada = 'Todos';
  String _filtroNombre = '';
  File? _imageFile;
  String? _imageUrlManual;
  final ImagePicker _picker = ImagePicker();
  String? _editId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarNombreAdmin();
  }

  Future<void> _cargarNombreAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    }
  }

  Future<void> _seleccionarImagen() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final ext = path.extension(pickedFile.path).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageUrlManual = null;
          _urlController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formato no válido. Usa JPG, PNG o GIF.')),
        );
      }
    }
  }

  Future<String?> _subirImagen(File imagen) async {
    try {
      final fileName = path.basename(imagen.path);
      final ref = FirebaseStorage.instance.ref().child('productos/$fileName');
      await ref.putFile(imagen);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
      return null;
    }
  }

  Future<void> _guardarProducto() async {
    final nombre = _nombreController.text.trim();
    final precioTexto = _precioController.text.trim();
    final urlManual = _urlController.text.trim();

    if (nombre.isEmpty || precioTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    final precio = double.tryParse(precioTexto);
    if (precio == null) return;

    String imageUrl = 'https://via.placeholder.com/150';
    if (_imageFile != null) {
      final url = await _subirImagen(_imageFile!);
      if (url != null) imageUrl = url;
    } else if (urlManual.isNotEmpty) {
      imageUrl = urlManual;
    }

    final data = {
      'name': nombre,
      'price': precio,
      'category': _categoriaSeleccionada == 'Todos' ? 'Menú' : _categoriaSeleccionada,
      'image': imageUrl,
    };

    if (_editId != null) {
      await _productService.updateProduct(_editId!, data);
    } else {
      await _productService.addProduct(data);
    }

    _resetFormulario();
    _tabController.animateTo(0);
  }

  void _resetFormulario() {
    setState(() {
      _editId = null;
      _imageFile = null;
      _imageUrlManual = null;
      _urlController.clear();
      _nombreController.clear();
      _precioController.clear();
    });
  }

  Future<void> _eliminarProducto(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Eliminar producto?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Eliminar"),
          )
        ],
      ),
    );
    if (confirm == true) {
      await _productService.deleteProduct(id);
    }
  }

  Future<void> _exportarPDF(List<Map<String, dynamic>> productos) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Lista de Productos - $_categoriaSeleccionada',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Table.fromTextArray(
            headers: ['Nombre', 'Precio', 'Categoría'],
            data: productos.map((p) => [
              p['name'],
              'S/ ${p['price']}',
              p['category'],
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _buildListaProductos() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 900;
        final crossAxisCount = constraints.maxWidth > 1200
            ? 5
            : constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                    ? 3
                    : 2;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar producto...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: (val) => setState(() => _filtroNombre = val.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _categoriaSeleccionada,
                      items: ['Todos', ..._categorias]
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) => setState(() => _categoriaSeleccionada = val!),
                      icon: const Icon(Icons.filter_list, color: Colors.deepPurple),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _categoriaSeleccionada == 'Todos'
                    ? _productService.getAllProducts()
                    : _productService.getProductsByCategory(_categoriaSeleccionada),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final productos = snapshot.data!
                      .where((p) => p['name'].toString().toLowerCase().contains(_filtroNombre))
                      .toList();

                  if (productos.isEmpty) {
                    return const Center(
                        child: Text('😔 No hay productos registrados aún.',
                            style: TextStyle(fontSize: 16, color: Colors.grey)));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: isLargeScreen ? 310 : 265, //
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final p = productos[index];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(2, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Image.network(
                                p['image'],
                                height: isLargeScreen ? 160 : 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('S/ ${p['price']}',
                                      style: const TextStyle(
                                          color: Colors.green, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(p['category'],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                  onPressed: () {
                                    setState(() {
                                      _editId = p['id'];
                                      _nombreController.text = p['name'];
                                      _precioController.text = p['price'].toString();
                                      _categoriaSeleccionada = p['category'];
                                      _imageUrlManual = p['image'];
                                      _urlController.text = p['image'];
                                      _imageFile = null;
                                      _tabController.animateTo(1);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _eliminarProducto(p['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _editId != null ? '✏️ Editar producto' : '🆕 Agregar nuevo producto',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 30),
                  TextField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto',
                      prefixIcon: Icon(Icons.fastfood_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _precioController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio (S/)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _categoriaSeleccionada == 'Todos' ? 'Menú' : _categoriaSeleccionada,
                    items: _categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => _categoriaSeleccionada = val!),
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen (opcional)',
                      prefixIcon: Icon(Icons.link_outlined),
                    ),
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        setState(() {
                          _imageFile = null;
                          _imageUrlManual = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Seleccionar desde galería'),
                    onPressed: _seleccionarImagen,
                  ),
                  const SizedBox(height: 15),
                  if (_imageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover),
                    ),
                  if (_imageFile == null && _imageUrlManual != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_imageUrlManual!, height: 180, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _guardarProducto,
                      icon: const Icon(Icons.save),
                      label: Text(_editId != null ? 'Actualizar producto' : 'Guardar producto'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Productos'),
            Tab(icon: Icon(Icons.add_box_outlined), text: 'Agregar / Editar'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildListaProductos(), _buildFormulario()],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text("Exportar PDF"),
        onPressed: () async {
          final snapshot = await (_categoriaSeleccionada == 'Todos'
              ? _productService.getAllProducts().first
              : _productService.getProductsByCategory(_categoriaSeleccionada).first);

          if (snapshot.isNotEmpty) {
            await _exportarPDF(snapshot);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay productos para exportar.')),
            );
          }
        },
      ),
    );
  }
}
