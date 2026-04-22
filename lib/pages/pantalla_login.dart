import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        final role = doc.data()?['rol'] ?? '';
        await _actualizarTokenFCM(user.uid);
        if (!mounted) return;
        _navegarPorRol(role);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verificando sesión: $e')),
        );
      }
    }
  }

  Future<void> _actualizarTokenFCM(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Error FCM: $e');
    }
  }

  void _navegarPorRol(String role) {
    switch (role) {
      case 'admin':
        Navigator.pushReplacementNamed(context, '/admin-productos');
        break;
      case 'cliente':
        Navigator.pushReplacementNamed(context, '/select-table');
        break;
      case 'mesero':
        Navigator.pushReplacementNamed(context, '/pedidos-mesero');
        break;
      case 'cocina':
        Navigator.pushReplacementNamed(context, '/pedidos-cocina');
        break;
      default:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rol no definido')));
    }
  }

  Future<void> _loginWithFirebase() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _actualizarTokenFCM(cred.user!.uid);
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(cred.user!.uid)
          .get();
      _navegarPorRol(doc.data()?['rol'] ?? '');
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') mensaje = 'Usuario no registrado';
      if (e.code == 'wrong-password') mensaje = 'Contraseña incorrecta';
      if (e.code == 'invalid-email') mensaje = 'Correo inválido';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
  try {
    setState(() => _isLoading = true);

    UserCredential userCred;

    if (kIsWeb) {
      // ✅ LOGIN GOOGLE EN WEB con selector de cuenta
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.setCustomParameters({
        'prompt': 'select_account', // 🔹 fuerza elegir cuenta
      });

      userCred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } else {
      // ✅ LOGIN GOOGLE EN ANDROID / iOS con selector de cuenta
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      // Limpia sesión anterior para que siempre pregunte
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Usuario canceló el login
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
    }

    final user = userCred.user;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener el usuario de Google')),
        );
      }
      return;
    }

    // 🔹 Tu lógica centralizada
    await _procesarUsuarioGoogle(user);

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error login Google: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}



  Future<void> _loginWithFacebook() async {
    try {
      setState(() => _isLoading = true);
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final accessToken = result.accessToken!;
        final credential = FacebookAuthProvider.credential(accessToken.tokenString);
        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

        final docRef = FirebaseFirestore.instance.collection('usuarios').doc(userCred.user!.uid);
        final doc = await docRef.get();
        if (!doc.exists) {
          await docRef.set({
            'nombre': userCred.user!.displayName ?? '',
            'email': userCred.user!.email ?? '',
            'rol': 'cliente',
            'creado': Timestamp.now(),
          });
        }

        await _actualizarTokenFCM(userCred.user!.uid);
        if (!mounted) return;
        _navegarPorRol('cliente');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error login Facebook: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFC371)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: FadeTransition(
                      opacity: _animation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.8, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Column(
                                  children: [
                                    Image.asset(
                                      'lib/imgtaully/logo_ucv_restaurant.png',
                                      width: 180,
                                      height: 180,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '¡Bienvenido a UCV Restaurant!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Card(
                            elevation: 10,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: 'Correo',
                                      prefixIcon: const Icon(Icons.email),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock),
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _isLoading
                                      ? const CircularProgressIndicator()
                                      : Column(
                                          children: [
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.login),
                                                label: const Text("Ingresar"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.deepOrange,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12)),
                                                  minimumSize: const Size(double.infinity, 50),
                                                ),
                                                onPressed: _loginWithFirebase,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.g_mobiledata),
                                                label: const Text("Ingresar con Google"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12)),
                                                  minimumSize: const Size(double.infinity, 50),
                                                ),
                                                onPressed: _loginWithGoogle,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                icon: const Icon(Icons.facebook),
                                                label: const Text("Ingresar con Facebook"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.indigo,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12)),
                                                  minimumSize: const Size(double.infinity, 50),
                                                ),
                                                onPressed: _loginWithFacebook,
                                              ),
                                            ),
                                          ],
                                        ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(context, '/registro'),
                                    child: const Text("¿No tienes cuenta? Regístrate"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  
}Future<void> _procesarUsuarioGoogle(User user) async {
  final docRef =
      FirebaseFirestore.instance.collection('usuarios').doc(user.uid);

  final doc = await docRef.get();

  if (!doc.exists) {
    await docRef.set({
      'nombre': user.displayName ?? '',
      'email': user.email ?? '',
      'rol': 'cliente',
      'creado': Timestamp.now(),
    });
  }

  await _actualizarTokenFCM(user.uid);

  if (!mounted) return;
  _navegarPorRol('cliente');
}
}