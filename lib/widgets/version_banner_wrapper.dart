import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class VersionBannerWrapper extends StatefulWidget {
  final Widget child;
  const VersionBannerWrapper({super.key, required this.child});

  @override
  State<VersionBannerWrapper> createState() => _VersionBannerWrapperState();
}

class _VersionBannerWrapperState extends State<VersionBannerWrapper> {
  bool _bloquear = false;
  String _mensaje =
      'Tu aplicación está desactualizada. Debes actualizar para continuar.';

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('ucv_restaurant')
          .get();

      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final String minVersion = data['min_version'] ?? '1.0.0';
      final String mensaje = data['mensaje'] ?? _mensaje;

      // ✅ CAMBIA AQUÍ TU VERSIÓN ACTUAL
      const String currentVersion = '2.0.0';

      if (currentVersion.compareTo(minVersion) < 0) {
        setState(() {
          _bloquear = true;
          _mensaje = mensaje;
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_bloquear) return widget.child;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Actualización requerida',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mensaje,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // 👉 aquí luego podemos abrir Play Store / Web URL
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Actualizar ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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
}
