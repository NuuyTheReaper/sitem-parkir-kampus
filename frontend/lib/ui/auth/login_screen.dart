import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../admin/admin_dashboard.dart';
import '../mahasiswa/mahasiswa_dashboard.dart';
import '../petugas/petugas_dashboard.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final success = await ref.read(authProvider.notifier).login(
      _nimController.text,
      _passwordController.text,
    );

    if (success) {
      final role = ref.read(authProvider).role;
      if (!mounted) return;

      Widget nextScreen;
      if (role == 'admin') {
        nextScreen = const AdminDashboard();
      } else if (role == 'petugas') {
        nextScreen = const PetugasDashboard();
      } else {
        nextScreen = const MahasiswaDashboard();
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'Login gagal'),
          backgroundColor: AppTheme.maroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Row(
        children: [
          // ── Left Panel (hero) ──────────────────────────
          if (size.width > 700)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2A0808), Color(0xFF6B1515), Color(0xFF9A2020)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -60,
                      left: -60,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.03),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      right: -40,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 80,
                      right: 40,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.06), width: 2),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated parking icon
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                              ],
                            ),
                            child: const Icon(Icons.local_parking, size: 52, color: Colors.white),
                          ),
                          const SizedBox(height: 36),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFFFD4D4)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: const Text(
                              'Smart Campus\nParking System',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sistem manajemen parkir kampus\nterintegrasi dengan IoT & RFID',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Feature badges
                          _buildFeatureBadge(Icons.sensors, 'Akses RFID Real-time'),
                          const SizedBox(height: 12),
                          _buildFeatureBadge(Icons.shield_outlined, 'Verifikasi Kendaraan'),
                          const SizedBox(height: 12),
                          _buildFeatureBadge(Icons.bar_chart, 'Laporan & Statistik'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Right Panel (login form) ───────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFAF6F4), Color(0xFFF5F0ED)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo for mobile
                            if (size.width <= 700) ...[
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.maroonDark, AppTheme.maroon],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.maroon.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Icon(Icons.local_parking, size: 36, color: Colors.white),
                              ),
                              const SizedBox(height: 28),
                            ],
                            const Text(
                              'Selamat Datang 👋',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.maroonDark,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Masuk ke akun Anda untuk melanjutkan',
                              style: TextStyle(fontSize: 15, color: Colors.grey[500], height: 1.4),
                            ),
                            const SizedBox(height: 40),

                            // NIM field
                            const Text('NIM / NPP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nimController,
                              decoration: InputDecoration(
                                hintText: 'Masukkan NIM atau NPP Anda',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.maroonSurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.badge_outlined, size: 20, color: AppTheme.maroon),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onSubmitted: (_) => _handleLogin(),
                              decoration: InputDecoration(
                                hintText: 'Masukkan password Anda',
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.maroonSurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.lock_outline, size: 20, color: AppTheme.maroon),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Login button — gradient
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.maroonDark, AppTheme.maroon, AppTheme.maroonLight],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.maroon.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: authState.isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Info footer
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.maroonSurface.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.maroon.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.maroon.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.info_outline, size: 16, color: AppTheme.maroon.withOpacity(0.7)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Login menggunakan NIM untuk mahasiswa, NPP untuk petugas & admin.',
                                      style: TextStyle(fontSize: 12, color: AppTheme.maroon.withOpacity(0.7), height: 1.4),
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
