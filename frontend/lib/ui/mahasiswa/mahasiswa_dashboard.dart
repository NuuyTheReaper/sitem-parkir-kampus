import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../shared/profile_tab.dart';
import '../shared/modern_components.dart';

class MahasiswaDashboard extends ConsumerStatefulWidget {
  const MahasiswaDashboard({super.key});

  @override
  ConsumerState<MahasiswaDashboard> createState() => _MahasiswaDashboardState();
}

class _MahasiswaDashboardState extends ConsumerState<MahasiswaDashboard> {
  int _currentIndex = 0;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _connectWS();
  }

  void _connectWS() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConstants.wsUrl));
      _channel!.stream.listen((message) {
        final decoded = jsonDecode(message);
        if (decoded['type'] == 'announcement') {
          _showAnnouncement(decoded['message'], decoded['sender']);
        }
      }, onError: (_) => Future.delayed(const Duration(seconds: 5), _connectWS));
    } catch (_) {}
  }

  void _showAnnouncement(String msg, String sender) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: AppTheme.maroon),
            const SizedBox(width: 8),
            const Text('Pengumuman Baru'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Text('Dari: $sender', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: AppTheme.headerGradient,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.local_parking, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard Mahasiswa', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      Text('Smart Campus Parking', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          StatusTab(),
          KendaraanTab(),
          HistoryTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.08))),
          boxShadow: [BoxShadow(color: AppTheme.maroon.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.local_parking_rounded, 'Status'),
                _buildNavItem(1, Icons.directions_car_rounded, 'Kendaraan'),
                _buildNavItem(2, Icons.history_rounded, 'Riwayat'),
                _buildNavItem(3, Icons.person_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.maroonSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: isSelected ? AppTheme.maroon : AppTheme.slate500),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.maroon : AppTheme.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── STATUS TAB ─────────────────────────────────────────────
class StatusTab extends ConsumerStatefulWidget {
  const StatusTab({super.key});

  @override
  ConsumerState<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends ConsumerState<StatusTab> {
  Future<Map<String, dynamic>> fetchStatus() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('mahasiswa/status-parkir');
    return response.data;
  }

  Future<List<dynamic>> fetchRequests() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('mahasiswa/my-requests');
    return response.data;
  }

  Future<void> _sendRequest(String action) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('mahasiswa/access-request', queryParameters: {'action': action});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permintaan $action dikirim ke petugas 📤'),
            backgroundColor: Colors.blue[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'),
          backgroundColor: AppTheme.maroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.maroon,
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            FutureBuilder<Map<String, dynamic>>(
              future: fetchStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: AppTheme.maroon)));
                }
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');

                final data = snapshot.data!;
                final status = data['status'] as String;
                final isParked = status == 'Sedang Parkir';
                final bool isFlagged = (data['is_flagged'] == true || data['is_flagged'] == 1);

                return Column(
                  children: [
                    if (isFlagged) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Akun Kamu Ditandai!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                                  Text(data['flag_reason'] ?? 'Pelanggaran peraturan parkir', style: TextStyle(color: Colors.red[700], fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isParked
                              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                              : [AppTheme.maroonDark, AppTheme.maroon],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isParked ? Colors.green : AppTheme.maroon).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  isParked ? Icons.local_parking_rounded : Icons.directions_walk_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status Parkir',
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                    ),
                                    Text(
                                      status,
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isParked ? Colors.greenAccent : Colors.orange,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: (isParked ? Colors.greenAccent : Colors.orange).withOpacity(0.6), blurRadius: 6)],
                                ),
                              ),
                            ],
                          ),
                          if (data['waktu_terakhir'] != null) ...[
                            const SizedBox(height: 12),
                            Divider(color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Text(
                                  'Update: ${data['waktu_terakhir']}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Request Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.maroonSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.send_rounded, color: AppTheme.maroon, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ajukan Permintaan Akses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.maroon)),
                            Text('Akan diverifikasi oleh petugas parkir', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sendRequest('masuk'),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Minta Masuk'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sendRequest('keluar'),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Minta Keluar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.maroon,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Announcements Section
            const Row(
              children: [
                Icon(Icons.campaign_rounded, size: 20, color: Colors.orange),
                SizedBox(width: 8),
                Text('Pengumuman Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: ref.read(dioProvider).get('mahasiswa/announcements').then((r) => r.data as List<dynamic>),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined, size: 32, color: Colors.grey[300]),
                        const SizedBox(height: 6),
                        const Text('Belum ada pengumuman', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: snapshot.data!.map<Widget>((ann) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.withOpacity(0.08), Colors.amber.withOpacity(0.04)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.campaign, color: Colors.orange, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ann['message'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Oleh: ${ann['sender'] ?? '-'} • ${ann['created_at'] ?? ''}',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Request history header
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 20, color: AppTheme.maroon),
                SizedBox(width: 8),
                Text('Riwayat Permintaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.maroon)),
              ],
            ),
            const SizedBox(height: 12),

            // History list
            FutureBuilder<List<dynamic>>(
              future: fetchRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.maroon));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          const Text('Belum ada permintaan', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.map<Widget>((r) {
                    final status = r['status'] as String;
                    final isMasuk = r['jenis_aktivitas'] == 'masuk';
                    final statusColor = AppTheme.statusColor(status);
                    final statusIcon = AppTheme.statusIcon(status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isMasuk ? Colors.green[50] : AppTheme.maroonSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isMasuk ? Icons.login_rounded : Icons.logout_rounded,
                                color: isMasuk ? Colors.green : AppTheme.maroon,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isMasuk ? 'Masuk' : 'Keluar',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: statusColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(r['waktu_request'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  if (r['catatan'] != null && r['catatan'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Catatan: ${r['catatan']}', style: const TextStyle(fontSize: 11, color: AppTheme.maroon)),
                                  ],
                                ],
                              ),
                            ),
                            Icon(statusIcon, color: statusColor),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── KENDARAAN TAB ──────────────────────────────────────────
class KendaraanTab extends ConsumerStatefulWidget {
  const KendaraanTab({super.key});

  @override
  ConsumerState<KendaraanTab> createState() => _KendaraanTabState();
}

class _KendaraanTabState extends ConsumerState<KendaraanTab> {
  Future<List<dynamic>> fetchVehicles() async {
    final response = await ref.read(dioProvider).get('mahasiswa/vehicles');
    return response.data;
  }

  Future<void> _uploadStnk(int vehicleId) async {
    // Use HTML file input for web
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((e) async {
        try {
          final bytes = reader.result as Uint8List;
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: file.name),
          });

          await ref.read(dioProvider).post(
            'mahasiswa/vehicles/$vehicleId/upload-stnk',
            data: formData,
          );

          if (!mounted) return;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Foto STNK berhasil diupload! 📸'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } catch (err) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal upload: $err'), backgroundColor: AppTheme.maroon),
          );
        }
      });
    });
  }

  void _showAddVehicleDialog() {
    String selectedType = 'Motor';
    final platController = TextEditingController();
    final merekController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.maroon.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.maroon, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Text('Daftar Kendaraan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.slate900)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Jenis Kendaraan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['Motor', 'Mobil'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.directions_car_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                const SizedBox(height: 16),
                const Text('Merek Kendaraan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate700)),
                const SizedBox(height: 8),
                TextField(
                  controller: merekController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Honda Vario, Toyota Avanza',
                    prefixIcon: const Icon(Icons.branding_watermark_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Plat Nomor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate700)),
                const SizedBox(height: 8),
                TextField(
                  controller: platController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: G 1234 AB',
                    prefixIcon: const Icon(Icons.credit_card_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.maroonSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.maroon.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: AppTheme.maroon.withOpacity(0.8)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kendaraan perlu diverifikasi oleh petugas parkir sebelum digunakan.',
                          style: TextStyle(fontSize: 12, color: AppTheme.maroon, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text('Batal', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.maroon,
                        ),
                        onPressed: () async {
                          if (platController.text.isEmpty || merekController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plat nomor dan Merek wajib diisi')));
                            return;
                          }
                          try {
                            await ref.read(dioProvider).post('mahasiswa/vehicles', data: {
                              'jenis_kendaraan': selectedType,
                              'plat_nomor': platController.text.toUpperCase(),
                              'merek': merekController.text,
                            });
                            if (!mounted) return;
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Kendaraan berhasil didaftarkan! 🚗'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                        child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F4),
      body: FutureBuilder<List<dynamic>>(
        future: fetchVehicles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerList(itemCount: 4, height: 120);
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return ModernEmptyState(
              icon: Icons.no_crash_outlined,
              title: 'Belum Ada Kendaraan',
              subtitle: 'Kamu belum mendaftarkan kendaraan apa pun.\nDaftarkan sekarang untuk mulai parkir.',
              actionLabel: 'Daftar Kendaraan',
              onAction: _showAddVehicleDialog,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final vehicle = snapshot.data![index];
              final status = vehicle['status_validasi'] as String;
              final statusColor = AppTheme.statusColor(status);
              final isMotor = vehicle['jenis_kendaraan'] == 'Motor';

              final hasStnk = vehicle['foto_stnk'] != null && vehicle['foto_stnk'].toString().isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppTheme.maroonSurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isMotor ? Icons.motorcycle_rounded : Icons.directions_car_rounded,
                              color: AppTheme.maroon, size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(vehicle['plat_nomor'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                Text(
                                  '${vehicle['jenis_kendaraan']}${vehicle['merek'] != null && vehicle['merek'].toString().isNotEmpty ? ' • ${vehicle['merek']}' : ''}',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppTheme.statusIcon(status), size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // STNK upload section
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasStnk ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasStnk ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                              size: 18,
                              color: hasStnk ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasStnk ? 'Foto STNK telah diupload ✓' : 'Upload foto STNK untuk verifikasi',
                                style: TextStyle(
                                  color: hasStnk ? Colors.green : Colors.orange[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (hasStnk)
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                onPressed: () => showStnkPhotoDialog(context, vehicle['foto_stnk']),
                                child: const Text('Lihat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.maroon,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _uploadStnk(vehicle['id']),
                              icon: Icon(hasStnk ? Icons.refresh : Icons.upload_rounded, size: 16),
                              label: Text(hasStnk ? 'Ganti' : 'Upload', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Daftar Kendaraan'),
      ),
    );
  }
}

// %% HISTORY TAB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  Future<List<dynamic>> _fetchHistory() async {
    final res = await ref.read(dioProvider).get('mahasiswa/riwayat-parkir');
    return res.data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F4),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerList(itemCount: 6, height: 80);
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const ModernEmptyState(
              icon: Icons.history_rounded,
              title: 'Belum Ada Riwayat',
              subtitle: 'Kamu belum memiliki riwayat aktivitas parkir.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final log = snapshot.data![index];
                final isMasuk = log['jenis_aktivitas'] == 'masuk';
                final date = DateTime.parse(log['waktu']).toLocal();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMasuk ? Colors.green.withOpacity(0.1) : AppTheme.maroon.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isMasuk ? Icons.login_rounded : Icons.logout_rounded,
                          color: isMasuk ? Colors.green : AppTheme.maroon,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMasuk ? 'Masuk Kampus' : 'Keluar Kampus',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(log['plat_nomor'], style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log['status_akses'].toString().replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

