// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';

// Ajusta estas importaciones según la ubicación real de tus providers
import '../cart.dart';
//import '../providers/selected_table.dart';

class AuthService {
  /// Muestra confirmación, cierra sesión en Firebase + Google + Facebook,
  /// opcionalmente limpia providers, y navega a /login (removiendo historial).
  static Future<void> confirmAndSignOut(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que quieres cerrar la sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    // Mostrar indicador de progreso modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) Firebase sign out
      await FirebaseAuth.instance.signOut();

      // 2) Google sign out (si fue usado)
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // no bloquear si falla
      }

      // 3) Facebook log out (si fue usado)
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {
        // no bloquear si falla
      }

      // 4) Limpiar providers (si tienes métodos para hacerlo)
      // Usa try/catch porque puede que tus clases tengan otro API.
      try {
        final cart = Provider.of<Cart>(context, listen: false);
        // si tu Cart tiene un método clear() descomenta la línea siguiente:
        // cart.clear();
      } catch (_) {}

      try {
       // final selectedTable = Provider.of<SelectedTable>(context, listen: false);
        // si SelectedTable tiene un método clear() descomenta:
        // selectedTable.clear();
      } catch (_) {}

      // Cerrar diálogo de progreso
      Navigator.of(context, rootNavigator: true).pop();

      // 5) Navegar a login y eliminar historial
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      // Cerrar diálogo de progreso
      Navigator.of(context, rootNavigator: true).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }
}