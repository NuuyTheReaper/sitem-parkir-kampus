import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/platform_file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../shared/profile_tab.dart';
import '../shared/modern_components.dart';
import '../shared/app_header.dart';
import '../shared/app_navbar.dart';

class MahasiswaDashboard extends ConsumerStatefulWidget {
  const MahasiswaDashboard({super.key});

  @override
  ConsumerState<MahasiswaDashboard> createState() => _MahasiswaDashboardState();
}

class _MahasiswaDashboardState extends ConsumerState<MahasiswaDashboard> {
  int _currentIndex = 0;
  WebSocketChannel? _channel;
  List<dynamic> _announcements = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _connectWS();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final response = await ref.read(dioProvider).get('mahasiswa/announcements');
      if (mounted) {
        setState(() {
          _announcements = (response.data as List<dynamic>?) ?? [];
          _unreadCount = _announcements.where((a) => a['is_read'] != true).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        setState(() {
          _announcements = [];
          _unreadCount = 0;
        });
      }
    }
  }

  void _connectWS() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConstants.wsUrl));
      _channel!.stream.listen((message) {
        final decoded = jsonDecode(message);
        if (decoded['type'] == 'announcement') {
          _showAnnouncementSnackbar(decoded['message'], decoded['sender']);
          _loadAnnouncements(); // Refresh announcements
        }
        if (mounted) {
          ref.read(refreshTriggerProvider.notifier).state++;
        }
      },
          onError: (_) =>
              Future.delayed(const Duration(seconds: 5), _connectWS));
    } catch (_) {}
  }

  void _showAnnouncementSnackbar(String msg, String sender) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pengumuman Baru',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(msg,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.maroon,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Lihat',
          textColor: Colors.white,
          onPressed: _showAnnouncementsSheet,
        ),
      ),
    );
  }

  void _showAnnouncementsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.maroonSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign,
                          color: AppTheme.maroon, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Pengumuman',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slate900)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.slate100,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Announcements list
              Expanded(
                child: _announcements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 64, color: AppTheme.slate300),
                            const SizedBox(height: 16),
                            Text('Belum ada pengumuman',
                                style: TextStyle(
                                    color: AppTheme.slate500, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: _announcements.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final ann = _announcements[index] as Map<String, dynamic>?;
                          if (ann == null) return const SizedBox.shrink();
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.slate50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.slate200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (ann['message'] ?? '').toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppTheme.slate900),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 14, color: AppTheme.slate500),
                                    const SizedBox(width: 4),
                                    Text(
                                      (ann['sender'] ?? '-').toString(),
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.slate500),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.access_time,
                                        size: 14, color: AppTheme.slate500),
                                    const SizedBox(width: 4),
                                    Text(
                                      (ann['created_at'] ?? '').toString(),
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.slate500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Mark all as read when sheet is closed
      setState(() {
        _unreadCount = 0;
      });
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Dashboard Mahasiswa',
        actions: [
          // Notification Bell with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _showAnnouncementsSheet,
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          NavBarItem(label: 'Home', icon: Icons.home_rounded),
          NavBarItem(label: 'Kendaraan', icon: Icons.directions_car_rounded),
          NavBarItem(label: 'Riwayat', icon: Icons.history_rounded),
          NavBarItem(label: 'Profil', icon: Icons.person_rounded),
        ],
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
      await dio.post('mahasiswa/access-request',
          queryParameters: {'action': action});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permintaan $action dikirim ke petugas 📤'),
            backgroundColor: Colors.blue[700],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshTriggerProvider);
    return RefreshIndicator(
      color: AppTheme.maroon,
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card Only
            FutureBuilder<Map<String, dynamic>>(
              future: fetchStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 200,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.maroon)));
                }
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');

                final data = snapshot.data!;
                final status = data['status'] as String;
                final isParked = status == 'Sedang Parkir';
                final bool isFlagged =
                    (data['is_flagged'] == true || data['is_flagged'] == 1);

                return Column(
                  children: [
                    // Warning Banner (if flagged)
                    if (isFlagged) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_rounded,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                  data['flag_reason'] ??
                                      'Akun ditandai - Pelanggaran peraturan',
                                  style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Main Status Card - Compact & Minimalist
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isParked
                              ? [const Color(0xFF15803D), const Color(0xFF16A34A)]
                              : [AppTheme.maroonDark, AppTheme.maroon],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isParked ? const Color(0xFF15803D) : AppTheme.maroon).withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon - Smaller
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isParked ? Icons.local_parking_rounded : Icons.directions_walk_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Status Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (data['waktu_terakhir'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    data['waktu_terakhir'],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Action Buttons - Outside Card
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sendRequest('masuk'),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Masuk',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: isParked ? const Color(0xFF16A34A) : AppTheme.maroon,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: AppTheme.slate200)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _sendRequest('keluar'),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Keluar',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.slate700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: AppTheme.slate200)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
              },
            ),
            
            const SizedBox(height: 24),

            // Request history header
            Text('Riwayat Permintaan',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                    letterSpacing: -0.3)),
            const SizedBox(height: 16),

            // History list
            FutureBuilder<List<dynamic>>(
              future: fetchRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppTheme.maroon));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Center(
                      child: Text('Belum ada permintaan',
                          style: TextStyle(
                              color: AppTheme.slate500, fontSize: 13)),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.map<Widget>((r) {
                    final status = r['status'] as String;
                    final isMasuk = r['jenis_aktivitas'] == 'masuk';
                    final statusColor = AppTheme.statusColor(status);
                    final statusIcon = AppTheme.statusIcon(status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isMasuk
                                    ? Colors.green[50]
                                    : AppTheme.maroonSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isMasuk
                                    ? Icons.login_rounded
                                    : Icons.logout_rounded,
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
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color:
                                                  statusColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(r['waktu_request'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  if (r['catatan'] != null &&
                                      r['catatan'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Catatan: ${r['catatan']}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.maroon)),
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
    try {
      final file = await pickImageFile();
      if (file == null) return;

      final extension = file.name.split('.').last.toLowerCase();
      final mimeSubtype = extension == 'png' ? 'png' : (extension == 'webp' ? 'webp' : 'jpeg');

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes, 
          filename: file.name,
          contentType: MediaType('image', mimeSubtype),
        ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload: $err'),
          backgroundColor: AppTheme.maroon,
        ),
      );
    }
  }

  Future<void> _confirmDeleteVehicle(int vehicleId, String platNomor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
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
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Text('Hapus Kendaraan',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.slate900)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Apakah Anda yakin ingin menghapus kendaraan dengan plat nomor $platNomor?',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.slate700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tindakan ini juga akan menghapus riwayat parkir & request akses kendaraan ini.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500),
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
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text('Batal',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(dioProvider).delete('mahasiswa/vehicles/$vehicleId');
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Kendaraan berhasil dihapus!'),
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
          SnackBar(
            content: Text('Gagal menghapus kendaraan: $err'),
            backgroundColor: AppTheme.maroon,
          ),
        );
      }
    }
  }

  void _showAddVehicleDialog() {
    String selectedType = 'Motor';
    final platController = TextEditingController();
    final merekController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      child: const Icon(Icons.add_circle_outline_rounded,
                          color: AppTheme.maroon, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Text('Daftar Kendaraan',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.slate900)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Jenis Kendaraan',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.slate700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['Motor', 'Mobil']
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.directions_car_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                const SizedBox(height: 16),
                const Text('Merek Kendaraan',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.slate700)),
                const SizedBox(height: 8),
                TextField(
                  controller: merekController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Honda Vario, Toyota Avanza',
                    prefixIcon: const Icon(Icons.branding_watermark_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Plat Nomor',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.slate700)),
                const SizedBox(height: 8),
                TextField(
                  controller: platController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: G 1234 AB',
                    prefixIcon: const Icon(Icons.credit_card_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                      Icon(Icons.info_outline,
                          size: 20, color: AppTheme.maroon.withOpacity(0.8)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Kendaraan perlu diverifikasi oleh petugas parkir sebelum digunakan.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.maroon,
                              fontWeight: FontWeight.w500),
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
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text('Batal',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600)),
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
                          if (platController.text.isEmpty ||
                              merekController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Plat nomor dan Merek wajib diisi')));
                            return;
                          }
                          try {
                            await ref
                                .read(dioProvider)
                                .post('mahasiswa/vehicles', data: {
                              'jenis_kendaraan': selectedType,
                              'plat_nomor': platController.text.toUpperCase(),
                              'merek': merekController.text,
                            });
                            if (!mounted) return;
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Kendaraan berhasil didaftarkan! 🚗'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')));
                          }
                        },
                        child: const Text('Simpan',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
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
    ref.watch(refreshTriggerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<List<dynamic>>(
        future: fetchVehicles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.maroon));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.slate50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.directions_car_outlined,
                          size: 56, color: AppTheme.slate400),
                    ),
                    const SizedBox(height: 24),
                    Text('Belum Ada Kendaraan',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate900)),
                    const SizedBox(height: 8),
                    Text('Daftarkan kendaraan untuk mulai parkir',
                        style: TextStyle(fontSize: 14, color: AppTheme.slate500),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _showAddVehicleDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      child: const Text('Daftar Kendaraan'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final vehicle = snapshot.data![index];
              final status = vehicle['status_validasi'] as String;
              final statusColor = AppTheme.statusColor(status);
              final isMotor = vehicle['jenis_kendaraan'] == 'Motor';

              final hasStnk = vehicle['foto_stnk'] != null &&
                  vehicle['foto_stnk'].toString().isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.slate200),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.slate900.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.maroonSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isMotor
                                ? Icons.motorcycle_rounded
                                : Icons.directions_car_rounded,
                            color: AppTheme.maroon,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(vehicle['plat_nomor'],
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                      color: AppTheme.slate900,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 2),
                              Text(
                                '${vehicle['jenis_kendaraan']}${vehicle['merek'] != null && vehicle['merek'].toString().isNotEmpty ? ' • ${vehicle['merek']}' : ''}',
                                style: TextStyle(
                                    fontSize: 13, color: AppTheme.slate500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                          tooltip: 'Hapus Kendaraan',
                          onPressed: () => _confirmDeleteVehicle(
                            vehicle['id'],
                            vehicle['plat_nomor'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppTheme.statusIcon(status),
                              size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // STNK Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasStnk ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasStnk ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasStnk
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_outlined,
                            size: 20,
                            color: hasStnk ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasStnk
                                  ? 'STNK telah diupload'
                                  : 'Upload STNK',
                              style: TextStyle(
                                color: hasStnk
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFF59E0B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hasStnk)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF16A34A),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => showStnkPhotoDialog(
                                  context, vehicle['foto_stnk']),
                              child: const Text('Lihat',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          if (!hasStnk)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFF59E0B),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _uploadStnk(vehicle['id']),
                              child: const Text('Upload',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (index * 50).ms)
                  .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                  .slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        backgroundColor: AppTheme.maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Daftar Kendaraan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        elevation: 2,
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
    ref.watch(refreshTriggerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
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
                    boxShadow: [],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMasuk
                              ? Colors.green.withOpacity(0.1)
                              : AppTheme.maroon.withOpacity(0.1),
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(log['plat_nomor'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log['status_akses']
                                  .toString()
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600]),
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
