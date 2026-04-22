import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showCodigo = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _actualizarTokenFCM(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).set(
          {
            'fcmToken': token,
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      debugPrint('Error FCM: $e');
    }
  }

  /// 🔐 Busca en Firestore un documento de role_codes con ese código
  /// y devuelve { 'rol': 'mesero', 'docId': 'mesero' } o null si no existe/está inactivo
  Future<Map<String, String>?> _obtenerRolDesdeCodigo(String codigo) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('role_codes')
          .where('codigo', isEqualTo: codigo)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final data = doc.data();

      final String? rol = data['role'] as String?;
      if (rol == null || rol.isEmpty) return null;

      return {
        'rol': rol,
        'docId': doc.id,
      };
    } catch (e) {
      debugPrint('Error leyendo código de rol: $e');
      return null;
    }
  }

  Future<void> _registrarUsuarioConRol() async {
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text.trim();
    final codigo = _codigoController.text.trim();

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    if (codigo.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Debes ingresar un código de rol (obligatorio).")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔐 Buscar rol real en Firestore
      final rolData = await _obtenerRolDesdeCodigo(codigo);
      if (rolData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Código inválido o desactivado. Consulta con el administrador.",
            ),
          ),
        );
        return;
      }

      final String rol = rolData['rol']!;
      final String roleDocId = rolData['docId']!;

      // ✅ Verificar si el correo ya existe
      final existing = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .get();
      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Este correo ya está registrado")),
        );
        return;
      }

      // ✅ Crear usuario en Auth
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // ✅ Guardar datos en usuarios
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCred.user!.uid)
          .set({
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'creado': Timestamp.now(),
      });

      await _actualizarTokenFCM(userCred.user!.uid);

      // 🔐 Opcional: marcar el código como usado (para un solo uso)
      try {
        await FirebaseFirestore.instance
            .collection('role_codes')
            .doc(roleDocId)
            .update({
          'active': false,
          'usedBy': userCred.user!.uid,
          'usedAt': Timestamp.now(),
        });
      } catch (e) {
        debugPrint('No se pudo marcar el código como usado: $e');
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("¡Registro exitoso!"),
          content: Text("Bienvenido $rol: $nombre"),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              child: const Text("Ir al login"),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al registrar';
      if (e.code == 'email-already-in-use') {
        mensaje = 'Este correo ya está registrado';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña debe tener al menos 6 caracteres';
      } else if (e.code == 'invalid-email') {
        mensaje = 'Correo inválido';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error inesperado: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navegarPorRol(String rol) {
    switch (rol) {
      case 'admin':
        Navigator.pushReplacementNamed(context, '/admin-productos');
        break;
      case 'cliente':
        Navigator.pushReplacementNamed(context, '/home-cliente');
        break;
      case 'mesero':
        Navigator.pushReplacementNamed(context, '/pedidos-mesero');
        break;
      case 'cocina':
        Navigator.pushReplacementNamed(context, '/pedidos-cocina');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/home-cliente');
    }
  }

  // ---- Registro con Google ----
  Future<void> _registroGoogle() async {
    try {
      setState(() => _isLoading = true);

      UserCredential userCred;

      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });

        userCred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email'],
          signInOption: SignInOption.standard,
          forceCodeForRefreshToken: true,
        );

        await googleSignIn.signOut();

        final GoogleSignInAccount? googleUser =
            await googleSignIn.signIn();
        if (googleUser == null) return;

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final docRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCred.user!.uid);
      final doc = await docRef.get();

      String rol;
      if (doc.exists && doc.data()!.containsKey('rol')) {
        rol = doc['rol'];
      } else {
        rol = 'cliente';
        await docRef.set({
          'nombre': userCred.user?.displayName ?? 'Cliente Google',
          'email': userCred.user?.email ?? '',
          'rol': rol,
          'creado': Timestamp.now(),
        });
      }

      await _actualizarTokenFCM(userCred.user!.uid);

      if (!mounted) return;
      _navegarPorRol(rol);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error con Google: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registroFacebook() async {
    try {
      setState(() => _isLoading = true);
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status != LoginStatus.success) return;

      final OAuthCredential facebookCredential =
          FacebookAuthProvider.credential(result.accessToken!.tokenString);
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(facebookCredential);

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCred.user!.uid)
          .get();

      String rol;
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!.containsKey('rol')) {
        rol = doc.data()!['rol'] as String;
      } else {
        rol = 'cliente';
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userCred.user!.uid)
            .set({
          'nombre': userCred.user?.displayName ?? 'Cliente Facebook',
          'email': userCred.user?.email ?? '',
          'rol': rol,
          'creado': Timestamp.now(),
        });
      }

      await _actualizarTokenFCM(userCred.user!.uid);

      if (!mounted) return;
      _navegarPorRol(rol);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error con Facebook: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFffe5d4), Color(0xFFffdac1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    shadowColor: Colors.black26,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Crear cuenta',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildOAuthButtons(),
                          const SizedBox(height: 16),
                          _buildDividerText('O registrar por correo'),
                          const SizedBox(height: 16),
                          _buildTextField(
                            _nombreController,
                            'Nombre completo',
                            Icons.person,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            _emailController,
                            'Correo electrónico',
                            Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            _passController,
                            'Contraseña',
                            Icons.lock,
                            obscureText: !_showPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            _codigoController,
                            'Código de rol (obligatorio)',
                            Icons.vpn_key,
                            obscureText: !_showCodigo,
                            hintText:
                                'Código entregado por el administrador',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showCodigo
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  setState(() => _showCodigo = !_showCodigo),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _registrarUsuarioConRol,
                              icon: const Icon(Icons.person_add),
                              label: const Text("Registrar con correo"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              "Si deseas registrarte como CLIENTE sin código, usa el registro con Google o Facebook.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child:
                    CircularProgressIndicator(color: Colors.deepOrange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withOpacity(0.95),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildDividerText(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
        ),
        const Expanded(child: Divider(thickness: 1)),
      ],
    );
  }

  Widget _buildOAuthButtons() {
    return _isLoading
        ? const SizedBox()
        : Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text("Registrar con Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _registroGoogle,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.facebook),
                  label: const Text("Registrar con Facebook"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _registroFacebook,
                ),
              ),
            ],
          );
  }
}
