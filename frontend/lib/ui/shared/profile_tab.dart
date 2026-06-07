import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../auth/login_screen.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  String _currentScreen = 'main'; // main, account, security, changePassword
  late Future<Map<String, dynamic>?> _profileFuture;
  late final TextEditingController _oldPwCtrl;
  late final TextEditingController _newPwCtrl;
  late final TextEditingController _confirmPwCtrl;

  @override
  void initState() {
    super.initState();
    _profileFuture = ref.read(authProvider.notifier).getProfile();
    _oldPwCtrl = TextEditingController();
    _newPwCtrl = TextEditingController();
    _confirmPwCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }


  // Menyesuaikan menu tile capsule melengkung penuh sesuai gambar
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), // Membuat bentuk capsule rounded murni
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: iconColor ?? Colors.black87, // FIXED: black80 diubah ke black87
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: iconColor ?? Colors.black87, // FIXED: black80 diubah ke black87
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Menyesuaikan baris detail info dengan garis bawah tipis (Divider) sesuai gambar
  Widget _buildDetailRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87, // FIXED: black80 diubah ke black87
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: Colors.grey[200],
            height: 1,
            thickness: 1,
          ),
      ],
    );
  }

  Widget _buildMainScreen(Map<String, dynamic> profile) {
    final bool isMahasiswa = profile['role'] == 'mahasiswa';

    return Scaffold(
      backgroundColor: AppTheme.maroon, // Background utama atas berwarna maroon
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER SECTION WITH DECORATIONS ---
            Stack(
              children: [
                // Ornamen Lingkaran Kanan Atas
                Positioned(
                  top: -50,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Ornamen Lingkaran Kiri Bawah Header
                Positioned(
                  bottom: 20,
                  left: -60,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Konten Header Utama
                SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 10, bottom: 25),
                    child: Column(
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Avatar dengan Edit Overlay Icon
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white38,
                                shape: BoxShape.circle,
                              ),
                              child: const CircleAvatar(
                                radius: 52,
                                backgroundColor: AppTheme.maroonSurface,
                                child: Icon(
                                  IconlyLight.profile,
                                  size: 55,
                                  color: AppTheme.maroon,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile['nama'] ?? 'gobed',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isMahasiswa ? "NIM" : "NPP"}: ${profile['nim_npp']}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // --- BODY CONTENT SECTION (White Rounded Container) ---
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA), // Latar belakang abu-abu terang soft sesuai mockup
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                children: [
                  // White Box Container untuk detail data profil
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 24), // FIXED: sintaks margin dibetulkan
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Full name', profile['nama'] ?? '-'),
                        _buildDetailRow('Username', profile['role'].toString().toLowerCase()),
                        _buildDetailRow(isMahasiswa ? 'NIM' : 'NPP', profile['nim_npp'] ?? '-'),
                        _buildDetailRow('Status', 'Aktif', isLast: true),
                      ],
                    ),
                  ),

                  // Menu list actions berbentuk capsule murni
                  _buildMenuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Informasi Akun',
                    onTap: () => setState(() => _currentScreen = 'account'),
                  ),
                  _buildMenuTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Ganti Password',
                    onTap: () => setState(() => _currentScreen = 'changePassword'),
                  ),
                  _buildMenuTile(
                    icon: IconlyLight.logout,
                    title: 'Keluar',
                    iconColor: Colors.redAccent,
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoScreen(Map<String, dynamic> profile) {
    final bool isMahasiswa = profile['role'] == 'mahasiswa';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Informasi Akun', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => setState(() => _currentScreen = 'main'),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _buildDetailRow('Nama', profile['nama']),
              _buildDetailRow(isMahasiswa ? 'NIM' : 'NPP', profile['nim_npp']),
              _buildDetailRow('Role', profile['role'].toString().toUpperCase()),
              if (isMahasiswa) ...[
                _buildDetailRow('Program Studi', profile['prodi_nama'] ?? '-'),
                _buildDetailRow('Semester', '${profile['semester'] ?? '-'}'),
              ],
              _buildDetailRow('Status', 'Aktif', isLast: true),
            ],
          ),
        ),
      ),
    );
  }

  void _clearPasswordFields() {
    _oldPwCtrl.clear();
    _newPwCtrl.clear();
    _confirmPwCtrl.clear();
  }

  Widget _buildChangePasswordScreen() {
    bool isLoading = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    return StatefulBuilder(
      builder: (context, setScreenState) => Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Ganti Password', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
            onPressed: () {
              _clearPasswordFields();
              setState(() => _currentScreen = 'main');
            },
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _oldPwCtrl,
                obscureText: obscureOld,
                decoration: InputDecoration(
                  labelText: 'Password Lama',
                  prefixIcon: const Icon(IconlyLight.lock, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setScreenState(() => obscureOld = !obscureOld),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPwCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Password Baru',
                  prefixIcon: const Icon(Icons.lock_open_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setScreenState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPwCtrl,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password Baru',
                  prefixIcon: const Icon(Icons.lock_clock_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setScreenState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Password minimal 6 karakter',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (_newPwCtrl.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password baru minimal 6 karakter')),
                            );
                            return;
                          }
                          if (_newPwCtrl.text != _confirmPwCtrl.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Konfirmasi password tidak cocok')),
                            );
                            return;
                          }
                          setScreenState(() => isLoading = true);
                          try {
                            await ref.read(dioProvider).post('auth/change-password', data: {
                              'old_password': _oldPwCtrl.text,
                              'new_password': _newPwCtrl.text,
                            });
                            if (!context.mounted) return;
                            _clearPasswordFields();
                            setState(() => _currentScreen = 'main');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password berhasil diubah'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            setScreenState(() => isLoading = false);
                            if (!context.mounted) return;
                            String msg = 'Gagal mengubah password';
                            if (e.toString().contains('400')) {
                              msg = 'Password lama salah';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: AppTheme.maroon),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Simpan Perubahan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.maroon));
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: Text('Gagal memuat profil'));
        }

        switch (_currentScreen) {
          case 'account':
            return _buildAccountInfoScreen(profile);
          case 'changePassword':
            return _buildChangePasswordScreen();
          default:
            return _buildMainScreen(profile);
        }
      },
    );
  }
}