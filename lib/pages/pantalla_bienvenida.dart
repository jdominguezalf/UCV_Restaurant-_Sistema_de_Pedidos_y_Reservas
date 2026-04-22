import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

class PantallaBienvenida extends StatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _floatImage;
  late final VideoPlayerController _videoController;

  double _textOpacity = 0.0;
  Offset _textOffset = const Offset(0, -0.2);
  bool _isCheckingSession = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeAnimation();
    _animateText();
  }

 void _initializeVideo() {
  _videoController = VideoPlayerController.asset(
    'assets/videos/logo_ucv_restaurant.mp4',
  );

  _videoController.initialize().then((_) {
    if (!mounted) return;
    setState(() {});

    // ▶ Reproducir una sola vez
    _videoController.play();

    _videoController.addListener(() {
      if (!_videoController.value.isPlaying &&
          _videoController.value.position ==
              _videoController.value.duration) {
        
        _videoController.pause();
      }
    });
  });

  
  _videoController.setLooping(false);
}



  void _initializeAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatImage = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: const Offset(0, 0.02),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _animateText() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _textOpacity = 1.0;
        _textOffset = Offset.zero;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (_isCheckingSession) return;

    setState(() => _isCheckingSession = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isCheckingSession = false);
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final role = doc.data()?['rol'] ?? '';

      if (!mounted) return;

      switch (role) {
        case 'cliente':
          Navigator.pushReplacementNamed(context, '/select-table');
          break;
        case 'mesero':
          Navigator.pushReplacementNamed(context, '/pedidos-mesero');
          break;
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin-productos');
          break;
        case 'cocina':
          Navigator.pushReplacementNamed(context, '/pedidos-cocina');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al verificar sesión: $e'),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } finally {
      if (mounted) {
        setState(() => _isCheckingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF7043), // naranja intenso
              Color(0xFFFFAB91), // naranja suave
              Color(0xFFFFFFFF), // blanco
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Círculos decorativos difuminados
            Positioned(
              top: -70,
              left: -40,
              child: _DecorativeCircle(size: 190),
            ),
            Positioned(
              bottom: -90,
              right: -60,
              child: _DecorativeCircle(size: 230),
            ),

            // Contenido principal
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: size.width > 500 ? 460 : double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 26,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // mini encabezado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.restaurant_menu,
                                    color: Color(0xFFFF5722), size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Bienvenido a',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF607D8B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Logo animado
                            SlideTransition(
                              position: _floatImage,
                              child: _videoController.value.isInitialized
                                  ? Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFFCC80),
                                            Color(0xFFFF7043),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.18),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: SizedBox(
                                          width: 150,
                                          height: 150,
                                          child: AspectRatio(
                                            aspectRatio: _videoController
                                                .value.aspectRatio,
                                            child: VideoPlayer(_videoController),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const CircularProgressIndicator(),
                            ),

                            const SizedBox(height: 22),

                            // Textos
                            AnimatedSlide(
                              offset: _textOffset,
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOut,
                              child: AnimatedOpacity(
                                opacity: _textOpacity,
                                duration: const Duration(milliseconds: 800),
                                child: Column(
                                  children: const [
                                    Text(
                                      'UCV Restaurant',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF263238),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Tu experiencia gastronómica digital',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF546E7A),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Mesas, pedidos y cocina conectados\n'
                                      'en tiempo real dentro del campus.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF78909C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Píldoras de features
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: const [
                                _FeaturePill(
                                  icon: Icons.table_bar_outlined,
                                  label: 'Gestión de mesas',
                                ),
                                _FeaturePill(
                                  icon: Icons.receipt_long_outlined,
                                  label: 'Pedidos rápidos',
                                ),
                                _FeaturePill(
                                  icon: Icons.kitchen_outlined,
                                  label: 'Cocina conectada',
                                ),
                              ],
                            ),

                            const SizedBox(height: 26),

                            // Botón principal
                            SizedBox(
                              width: 240,
                              child: ElevatedButton(
                                onPressed:
                                    _isCheckingSession ? null : _checkSession,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5722),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      const Color(0xFFFF5722).withOpacity(0.4),
                                ),
                                child: _isCheckingSession
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Verificando...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Comenzar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              'Desarrollado para la Universidad César Vallejo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF90A4AE),
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
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double size;
  const _DecorativeCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.20),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFCC80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFF8A65)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5D4037),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
