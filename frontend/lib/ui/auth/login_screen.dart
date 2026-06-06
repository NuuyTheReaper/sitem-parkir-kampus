import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nimController.dispose();
    _passwordController.dispose();
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 900;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bglogin.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading image: $error');
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF8F9FA),
                        Colors.white,
                        Color(0xFFF1F3F5),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.16),
                  ],
                ),
              ),
            ),
          ),
          if (isMobile)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      AppTheme.maroonDark.withValues(alpha: 0.68),
                      AppTheme.maroon.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Row(
              children: [
                if (!isMobile)
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                stops: const [0.0, 0.52, 1.0],
                                colors: [
                                  AppTheme.maroonDark.withValues(alpha: 0.82),
                                  AppTheme.maroon.withValues(alpha: 0.36),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.46),
                                  Colors.black.withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 80),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Smart Campus\nParking System',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Sistem manajemen parkir kampus\nterintegrasi dengan IoT & RFID',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    height: 1.6,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 56),
                                _buildModernFeature('Akses RFID Real-time'),
                                const SizedBox(height: 18),
                                _buildModernFeature('Verifikasi Kendaraan'),
                                const SizedBox(height: 18),
                                _buildModernFeature('Laporan & Statistik'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  flex: isMobile ? 1 : 4,
                  child: Container(
                    color: isMobile ? null : Colors.white,
                    child: SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 24 : 56,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 440),
                            child: Column(
                              children: [
                                if (isMobile) ...[
                                  const Text(
                                    'Smart Campus\nParking System',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                      letterSpacing: 0,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          offset: Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sistem manajemen parkir kampus\nterintegrasi dengan IoT & RFID',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      height: 1.5,
                                      letterSpacing: 0,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black26,
                                          offset: Offset(0, 1),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 24 : 36),
                                  decoration: isMobile
                                      ? BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.94),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.slate900
                                                  .withValues(alpha: 0.12),
                                              blurRadius: 30,
                                              offset: const Offset(0, 18),
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.slate900,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Masuk ke akun Anda untuk melanjutkan',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.slate500,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 40),
                                      const Text(
                                        'NIM / NPP',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.slate700,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _nimController,
                                        style: const TextStyle(fontSize: 14),
                                        decoration: const InputDecoration(
                                          hintText: 'Masukkan NIM atau NPP',
                                          hintStyle: TextStyle(
                                              color: AppTheme.slate400),
                                          prefixIcon: Icon(
                                            Icons.badge_outlined,
                                            size: 20,
                                            color: AppTheme.slate400,
                                          ),
                                          filled: true,
                                          fillColor: AppTheme.slate50,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(12)),
                                            borderSide: BorderSide(
                                                color: AppTheme.slate200),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(12)),
                                            borderSide: BorderSide(
                                                color: AppTheme.slate200),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(12)),
                                            borderSide: BorderSide(
                                                color: AppTheme.maroon,
                                                width: 1.5),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Password',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.slate700,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        style: const TextStyle(fontSize: 14),
                                        onSubmitted: (_) => _handleLogin(),
                                        decoration: InputDecoration(
                                          hintText: 'Masukkan password',
                                          hintStyle: const TextStyle(
                                              color: AppTheme.slate400),
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                            size: 20,
                                            color: AppTheme.slate400,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              size: 20,
                                              color: AppTheme.slate400,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: AppTheme.slate50,
                                          border: const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(12)),
                                            borderSide: BorderSide(
                                                color: AppTheme.slate200),
                                          ),
                                          enabledBorder:
                                              const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(12)),
                                            borderSide: BorderSide(
                                                color: AppTheme.slate200),
                                          ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(12)),
                                            borderSide: BorderSide(
                                                color: AppTheme.maroon,
                                                width: 1.5),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: authState.isLoading
                                              ? null
                                              : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.maroon,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            disabledBackgroundColor:
                                                AppTheme.slate300,
                                          ),
                                          child: authState.isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : const Text(
                                                  'Masuk',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppTheme.slate50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.slate200,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 18,
                                              color: AppTheme.slate500,
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Login menggunakan NIM untuk mahasiswa, NPP untuk petugas & admin',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.slate600,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms, curve: Curves.easeOutCubic)
                        .slideY(begin: 0.05, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFeature(String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
