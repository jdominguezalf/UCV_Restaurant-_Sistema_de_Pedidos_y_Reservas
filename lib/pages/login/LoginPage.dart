import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class PantallaLogin extends StatelessWidget {
  const PantallaLogin({super.key});

  // ------------------- FACEBOOK (Clientes) -------------------
  Future<void> _signInWithFacebook(BuildContext context) async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login cancelado o fallido: ${result.status}')),
        );
        return;
      }

      final accessToken = result.accessToken;
      if (accessToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: no se obtuvo token de Facebook')),
        );
        return;
      }

      final credential = FacebookAuthProvider.credential(accessToken.tokenString);
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return;

      final docRef =
          FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'nombre': user.displayName ?? '',
          'email': user.email ?? '',
          'rol': 'cliente', // Facebook siempre cliente
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pushReplacementNamed(context, '/homeCliente');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error Facebook: $e')),
      );
    }
  }

  // ------------------- GOOGLE (Mesero/Admin/Cocina) -------------------
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // cancelado

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;

      final docRef =
          FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'nombre': user.displayName ?? '',
          'email': user.email ?? '',
          'rol': 'pendiente', // asignar manualmente en Firestore
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final role = (await docRef.get()).get('rol');
      switch (role) {
        case 'mesero':
          Navigator.pushReplacementNamed(context, '/pedidosMesero');
          break;
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        case 'cocina':
          Navigator.pushReplacementNamed(context, '/pedidosCocina');
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tienes acceso a la app')),
          );
          await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error Google: $e')),
      );
    }
  }

  // ------------------- WIDGET -------------------
  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(220, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 5,
      shadowColor: Colors.black26,
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE0B2), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ClipOval(
                  child: Image.asset(
                    'assets/images/logo op 2.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Bienvenido a UCV Restaurant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(height: 30),

                // Botón Facebook
                ElevatedButton.icon(
                  icon: const Icon(Icons.facebook),
                  label: const Text('Ingresar con Facebook'),
                  style: buttonStyle.copyWith(
                    backgroundColor: MaterialStateProperty.all(Colors.blue),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                  ),
                  onPressed: () => _signInWithFacebook(context),
                ),
                const SizedBox(height: 20),

                // Botón Google
                ElevatedButton.icon(
                  icon: const Icon(Icons.email),
                  label: const Text('Ingresar con Google'),
                  style: buttonStyle.copyWith(
                    backgroundColor: MaterialStateProperty.all(Colors.red),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                  ),
                  onPressed: () => _signInWithGoogle(context),
                ),

                const SizedBox(height: 30),

                // Registro manual opcional
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/registro');
                  },
                  child: const Text(
                    'Crear cuenta manual',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}