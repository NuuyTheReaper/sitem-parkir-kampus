import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../petugas/petugas_dashboard.dart';
import '../mahasiswa/mahasiswa_dashboard.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Run both session load and minimum splash delay in parallel
    await Future.wait([
      ref.read(authProvider.notifier).loadSession(),
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);
    
    if (!mounted) return;

    final authState = ref.read(authProvider);
    final role = authState.role;

    Widget nextScreen;
    if (role == 'admin') {
      nextScreen = const AdminDashboard();
    } else if (role == 'petugas') {
      nextScreen = const PetugasDashboard();
    } else if (role == 'mahasiswa') {
      nextScreen = const MahasiswaDashboard();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgMaroon = Color(0xFF6B1B26);
    const Color textBeige = Color(0xFFE2D0B8);

    return Scaffold(
      backgroundColor: bgMaroon, // Latar belakang merah gelap sesuai logo
      body: Stack(
        children: [
          // Background Pattern (subtle geometric lines)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _GeometricBackgroundPainter(),
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Image
                Image.asset(
                  'assets/images/logo.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                )
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 800.ms),

                const SizedBox(height: 40),

                // Main Title
                const Text(
                  'Sistem Manajemen\nParkir UHN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Georgia', // Serif font look
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: textBeige, // Krem/Beige color
                    height: 1.2,
                  ),
                )
                .animate(delay: 400.ms)
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),

                const SizedBox(height: 16),

                // Subtitle
                const Text(
                  'UNIVERSITAS HARKAT NEGERI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    color: textBeige, // Krem/Beige color
                  ),
                )
                .animate(delay: 600.ms)
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),
              ],
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textBeige),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading...',
                  style: TextStyle(
                    color: textBeige.withOpacity(0.8),
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            )
            .animate(delay: 1000.ms)
            .fadeIn(duration: 600.ms),
          ),
        ],
      ),
    );
  }
}

// A simple painter to draw some geometric lines in the background
class _GeometricBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height * 0.1);
    path.lineTo(size.width, size.height * 0.3);
    
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.9);
    path.lineTo(size.width, size.height * 0.7);

    path.moveTo(size.width * 0.2, 0);
    path.lineTo(size.width * 0.2, size.height);
    
    path.moveTo(size.width * 0.8, 0);
    path.lineTo(size.width * 0.8, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
