import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../shared/profile_tab.dart';
import '../shared/parking_chart.dart';
import '../shared/modern_components.dart';
import '../shared/web_mjpeg_viewer.dart';
import '../shared/app_header.dart';
import '../shared/app_navbar.dart';
import '../shared/filter_toggle.dart';

// Provider to force global refresh
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

// Provider to track pending request count for badge
final pendingCountProvider = StateProvider<int>((ref) => 0);

// Provider for activity chart data
final activityChartProvider = FutureProvider<List<dynamic>>((ref) async {
  ref.watch(refreshTriggerProvider); // Auto-refresh when triggered
  final res = await ref.read(dioProvider).get('petugas/activity-chart');
  return res.data as List<dynamic>;
});

class PetugasDashboard extends ConsumerStatefulWidget {
  const PetugasDashboard({super.key});

  @override
  ConsumerState<PetugasDashboard> createState() => _PetugasDashboardState();
}

class _PetugasDashboardState extends ConsumerState<PetugasDashboard> {
  int _currentIndex = 0;
  WebSocketChannel? _notifChannel;

  @override
  void initState() {
    super.initState();
    _refreshBadge();
    _connectNotificationWS();
  }

  void _connectNotificationWS() {
    try {
      _notifChannel =
          WebSocketChannel.connect(Uri.parse(AppConstants.wsNotifUrl));
      _notifChannel!.stream.listen((message) {
        try {
          final decoded = jsonDecode(message);
          if (decoded['type'] == 'new_access_request') {
            // Trigger global refresh for all tabs
            ref.read(refreshTriggerProvider.notifier).state++;

            // Increment badge immediately
            ref.read(pendingCountProvider.notifier).state++;
            // Show snackbar notification
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📥 Permintaan baru dari ${decoded['user_nama']} (${decoded['jenis_aktivitas']})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.maroon,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'LIHAT',
                    textColor: Colors.white,
                    onPressed: () => setState(() => _currentIndex = 1),
                  ),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('WS Notif Error: $e');
        }
      }, onError: (_) {
        // Reconnect after error
        Future.delayed(const Duration(seconds: 5), _connectNotificationWS);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _notifChannel?.sink.close();
    super.dispose();
  }

  Future<void> _refreshBadge() async {
    try {
      final res =
          await ref.read(dioProvider).get('petugas/access-requests/pending');
      final count = (res.data as List).length;
      ref.read(pendingCountProvider.notifier).state = count;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppHeader(
        title: 'Command Center',
        subtitle: 'Smart Parking System',
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ONLINE',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 22),
            onPressed: _refreshBadge,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const LiveMonitorTab(),
          PermintaanTabWithFilter(onCountChanged: _refreshBadge),
          const SearchMemberTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) _refreshBadge();
        },
        items: [
          const NavBarItem(label: 'Monitor', icon: Icons.monitor_rounded),
          NavBarItem(
            label: 'Permintaan',
            icon: Icons.pending_actions_rounded,
            badgeCount: pendingCount,
          ),
          const NavBarItem(label: 'Cari', icon: Icons.person_search_rounded),
          const NavBarItem(label: 'Profil', icon: Icons.account_circle_rounded),
        ],
      ),
    );
  }
}

class SessionStatsSummary extends ConsumerWidget {
  const SessionStatsSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(refreshTriggerProvider); // Rebuild & refetch on global refresh

    return FutureBuilder(
      future: Future.wait([
        ref.read(dioProvider).get('petugas/session-stats'),
        ref.read(dioProvider).get('gate/stats/capacity'),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
                children: List.generate(
                    3,
                    (_) => Expanded(
                          child: Container(
                            height: 80,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                                color: AppTheme.slate100,
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ))),
          );
        }
        final stats = ((snapshot.data?[0] as dynamic)?.data ??
            {"handled_count": 0, "pending_stnk": 0}) as Map<String, dynamic>;
        final capData = ((snapshot.data?[1] as dynamic)?.data ??
            {"parked": 0, "total": 100}) as Map<String, dynamic>;
        final parked = (capData['parked'] ?? 0) as int;
        final total = (capData['total'] ?? 100) as int;
        final percent = (parked / total).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              _StatCard(
                icon: Icons.directions_car_filled_rounded,
                label: 'Terisi',
                value: '$parked/$total',
                color: percent > 0.9
                    ? const Color(0xFFDC2626)
                    : (percent > 0.7 ? AppTheme.amber : AppTheme.emerald),
                progress: percent,
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.check_circle_rounded,
                label: 'Selesai',
                value: '${stats['handled_count']}',
                color: AppTheme.emerald,
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.assignment_late_rounded,
                label: 'STNK',
                value: '${stats['pending_stnk']}',
                color: AppTheme.amber,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double? progress;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.progress});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.slate200),
          boxShadow: [
            BoxShadow(
              color: AppTheme.slate900.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.slate500,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate900,
                    letterSpacing: -0.8)),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: progress!,
                    minHeight: 4,
                    backgroundColor: color.withOpacity(0.1),
                    color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── LIVE MONITOR TAB ───────────────────────────────────────
class LiveMonitorTab extends ConsumerStatefulWidget {
  const LiveMonitorTab({super.key});

  @override
  ConsumerState<LiveMonitorTab> createState() => _LiveMonitorTabState();
}

class _LiveMonitorTabState extends ConsumerState<LiveMonitorTab> {
  WebSocketChannel? channel;
  final List<Map<String, dynamic>> logs = [];
  String? _cameraUrl;
  bool _showCamera = false;

  @override
  void initState() {
    super.initState();
    try {
      channel = WebSocketChannel.connect(Uri.parse(AppConstants.wsUrl));
      channel!.stream.listen((message) {
        try {
          final decoded = jsonDecode(message);
          if (mounted) {
            setState(() {
              logs.insert(0, decoded);
              if (logs.length > 50) logs.removeLast();
            });
            // Trigger global refresh so capacity/chart update too
            ref.read(refreshTriggerProvider.notifier).state++;
          }
        } catch (e) {
          debugPrint('WS Live Monitor Error: $e');
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  void _showCameraDialog() {
    final urlCtrl = TextEditingController(text: _cameraUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.videocam_rounded, color: AppTheme.maroon),
            SizedBox(width: 8),
            Text('Koneksi Kamera'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL Stream Kamera',
                hintText: 'http://192.168.x.x:81/stream',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Masukkan URL MJPEG stream dari ESP32-CAM atau IP Camera Anda.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          if (_cameraUrl != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _cameraUrl = null;
                  _showCamera = false;
                });
                Navigator.pop(ctx);
              },
              child:
                  const Text('Putuskan', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon),
            onPressed: () {
              if (urlCtrl.text.isNotEmpty) {
                setState(() {
                  _cameraUrl = urlCtrl.text;
                  _showCamera = true;
                });
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.connected_tv, size: 16, color: Colors.white),
            label:
                const Text('Hubungkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartAsync = ref.watch(activityChartProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              // Quick Stats Row (capacity + handled + pending STNK)
              const SessionStatsSummary(),
              const SizedBox(height: 8),

              // Live Camera Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _showCamera && _cameraUrl != null
                                  ? Colors.greenAccent
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              boxShadow: [],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _showCamera && _cameraUrl != null
                                ? 'LIVE — Gate Camera'
                                : 'OFFLINE',
                            style: TextStyle(
                                color: _showCamera
                                    ? Colors.greenAccent
                                    : const Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showCameraDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      _showCamera
                                          ? Icons.settings_rounded
                                          : Icons.videocam_rounded,
                                      color: const Color(0xFF94A3B8),
                                      size: 14),
                                  const SizedBox(width: 5),
                                  Text(_showCamera ? 'Setting' : 'Connect',
                                      style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: _showCamera && _cameraUrl != null
                          ? ClipRRect(
                              borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20)),
                              child: WebMjpegViewer(streamUrl: _cameraUrl!),
                            )
                          : const Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam_outlined,
                                        color: Color(0xFF475569), size: 44),
                                    SizedBox(height: 10),
                                    Text('Kamera Belum Terhubung',
                                        style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    SizedBox(height: 4),
                                    Text('Tap "Connect" untuk menyambungkan',
                                        style: TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 11)),
                                  ]),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ALPR Terminal Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.document_scanner_rounded,
                          size: 16, color: AppTheme.emerald),
                    ),
                    const SizedBox(width: 10),
                    const Text('ALPR Output',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.slate900)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('${logs.length} scan',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.emerald,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ALPR Scan Results
              if (logs.isEmpty)
                Container(
                  height: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded,
                              size: 32, color: Color(0xFF334155)),
                          SizedBox(height: 8),
                          Text('Menunggu scan kendaraan...',
                              style: TextStyle(
                                  color: Color(0xFF475569), fontSize: 12)),
                        ]),
                  ),
                )
              else
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: logs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isSuccess = log['type'] == 'success';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: (isSuccess
                                      ? AppTheme.emerald
                                      : const Color(0xFFEF4444))
                                  .withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (isSuccess
                                        ? AppTheme.emerald
                                        : const Color(0xFFEF4444))
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                  isSuccess
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  color: isSuccess
                                      ? AppTheme.emerald
                                      : const Color(0xFFEF4444),
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['plate'] ?? 'UNKNOWN',
                                    style: const TextStyle(
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: Colors.white,
                                        letterSpacing: 2),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${log['message'] ?? '-'} • ${log['user'] ?? '-'}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isSuccess
                                        ? AppTheme.emerald
                                        : const Color(0xFFEF4444))
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isSuccess ? 'OK' : 'DENY',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isSuccess
                                        ? AppTheme.emerald
                                        : const Color(0xFFEF4444),
                                    letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              // Activity Chart
              chartAsync.when(
                data: (chartData) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
                  decoration: AppTheme.modernCard,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: AppTheme.tealLight,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.bar_chart_rounded,
                                size: 16, color: AppTheme.teal),
                          ),
                          const SizedBox(width: 10),
                          const Text('Tren Parkir (7 Hari)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppTheme.slate900)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ParkingChart(chartData: chartData),
                    ],
                  ),
                ),
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator())),
                error: (e, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
        // Emergency Override
        _buildEmergencyPanel(),
      ],
    );
  }

  Widget _buildEmergencyPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Emergency Override',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleEmergencyOpen('masuk'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.sensor_door, size: 18),
                  label: const Text('Buka Gate Masuk',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleEmergencyOpen('keluar'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.sensor_door, size: 18),
                  label: const Text('Buka Gate Keluar',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleEmergencyOpen(String gate) async {
    final reasonController = TextEditingController();
    bool confirmed = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Peringatan: Emergency $gate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Aksi ini akan membuka gerbang secara paksa dan dicatat oleh sistem.'),
                const SizedBox(height: 16),
                TextField(
                    controller: reasonController,
                    decoration:
                        const InputDecoration(hintText: 'Alasan darurat...')),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('YA, BUKA GERBANG'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      try {
        await ref.read(dioProvider).post('gate/emergency-action',
            queryParameters: {'gate': gate, 'reason': reasonController.text});
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gate $gate berhasil dibuka manual')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

// ── PERMINTAAN TAB WITH FILTER ─────────────────────────────
class PermintaanTabWithFilter extends ConsumerStatefulWidget {
  final VoidCallback? onCountChanged;
  const PermintaanTabWithFilter({super.key, this.onCountChanged});

  @override
  ConsumerState<PermintaanTabWithFilter> createState() =>
      _PermintaanTabWithFilterState();
}

class _PermintaanTabWithFilterState
    extends ConsumerState<PermintaanTabWithFilter> {
  String _selectedFilter = 'gerbang'; // 'gerbang' or 'stnk'

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Toggle
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilterToggle(
            options: const [
              FilterOption(
                value: 'gerbang',
                label: 'Permintaan Gerbang',
                icon: Icons.pending_actions_rounded,
              ),
              FilterOption(
                value: 'stnk',
                label: 'Verifikasi STNK',
                icon: Icons.verified_rounded,
              ),
            ],
            selectedValue: _selectedFilter,
            onChanged: (value) => setState(() => _selectedFilter = value),
          ),
        ),

        // Content based on filter
        Expanded(
          child: _selectedFilter == 'gerbang'
              ? AccessRequestQueueTab(onCountChanged: widget.onCountChanged)
              : const VerifikasiTab(),
        ),
      ],
    );
  }
}

// ── ACCESS REQUEST QUEUE TAB ───────────────────────────────
class AccessRequestQueueTab extends ConsumerStatefulWidget {
  final VoidCallback? onCountChanged;
  const AccessRequestQueueTab({super.key, this.onCountChanged});

  @override
  ConsumerState<AccessRequestQueueTab> createState() =>
      _AccessRequestQueueTabState();
}

class _AccessRequestQueueTabState extends ConsumerState<AccessRequestQueueTab> {
  Future<List<dynamic>> fetchPendingRequests() async {
    final response =
        await ref.read(dioProvider).get('petugas/access-requests/pending');
    return response.data;
  }

  Future<void> _respond(int requestId, String action,
      {String catatan = ''}) async {
    try {
      await ref.read(dioProvider).put(
        'petugas/access-requests/$requestId/respond',
        queryParameters: {'action': action, 'catatan': catatan},
      );
      if (mounted) {
        final msg = action == 'disetujui'
            ? '✓ Disetujui, gate dibuka'
            : '✗ Permintaan ditolak';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor:
                action == 'disetujui' ? Colors.green : AppTheme.maroon,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        widget.onCountChanged?.call();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  final List<String> _quickReasons = [
    "STNK Kadaluarsa",
    "Foto STNK Buram",
    "Plat Nomor Tidak Sesuai",
    "Bukan Mahasiswa Aktif",
    "Pajak Kendaraan Mati"
  ];

  void _showRejectDialog(int requestId) {
    final catatanController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppTheme.maroon),
              SizedBox(width: 8),
              Text('Tolak Permintaan'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alasan Cepat:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReasons
                      .map((reason) => GestureDetector(
                            onTap: () {
                              catatanController.text = reason;
                              setStateDialog(() {});
                            },
                            child: Chip(
                              label: Text(reason,
                                  style: const TextStyle(fontSize: 10)),
                              backgroundColor: catatanController.text == reason
                                  ? AppTheme.maroon.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text('Alasan penolakan (opsional):'),
                const SizedBox(height: 4),
                TextField(
                  controller: catatanController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Tulis alasan di sini...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon),
              onPressed: () {
                Navigator.pop(ctx);
                _respond(requestId, 'ditolak', catatan: catatanController.text);
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Tolak'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshTriggerProvider); // Auto-refresh when WS event occurs

    return RefreshIndicator(
      color: AppTheme.maroon,
      onRefresh: () async {
        ref.read(refreshTriggerProvider.notifier).state++;
        widget.onCountChanged?.call();
      },
      child: FutureBuilder<List<dynamic>>(
        future: fetchPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.maroon));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(Icons.check_circle_outline_rounded,
                'Tidak ada permintaan\nyang menunggu');
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final r = snapshot.data![index];
              final isMasuk = r['jenis_aktivitas'] == 'masuk';
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isMasuk
                                  ? Colors.green.withOpacity(0.1)
                                  : AppTheme.maroonSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isMasuk
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                              color: isMasuk ? Colors.green : AppTheme.maroon,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['user_nama'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Text('NIM: ${r['user_nim']}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isMasuk ? Colors.green : AppTheme.maroon,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isMasuk ? 'MASUK' : 'KELUAR',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (r['is_flagged'] == true)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3))),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'PERINGATAN: ${r['flag_reason'] ?? "User ini ditandai oleh petugas."}',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F4F4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: _InfoChip(
                                    icon: Icons.directions_car,
                                    label:
                                        '${r['vehicle_jenis']} • ${r['vehicle_plat']}')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _InfoChip(
                                    icon: Icons.nfc,
                                    label: r['rfid_uid'] ?? 'No RFID')),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '🕐 ${r['waktu_request'] ?? '-'}',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.maroon,
                                side: const BorderSide(color: AppTheme.maroon),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showRejectDialog(r['id']),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _respond(r['id'], 'disetujui'),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Setujui & Buka Gate'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── VERIFIKASI STNK TAB ────────────────────────────────────
class VerifikasiTab extends ConsumerStatefulWidget {
  const VerifikasiTab({super.key});

  @override
  ConsumerState<VerifikasiTab> createState() => _VerifikasiTabState();
}

class _VerifikasiTabState extends ConsumerState<VerifikasiTab> {
  Future<List<dynamic>> fetchPending() async {
    final response =
        await ref.read(dioProvider).get('petugas/vehicles/pending');
    return response.data;
  }

  Future<void> _updateStatus(int id, String status) async {
    try {
      await ref
          .read(dioProvider)
          .put('petugas/vehicles/$id/verify?status=$status');
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'disetujui'
            ? '✓ Kendaraan disetujui'
            : '✗ Kendaraan ditolak'),
        backgroundColor: status == 'disetujui' ? Colors.green : AppTheme.maroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.maroon,
      onRefresh: () async => setState(() {}),
      child: FutureBuilder<List<dynamic>>(
        future: fetchPending(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.maroon));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(Icons.fact_check_outlined,
                'Tidak ada kendaraan\nyang menunggu verifikasi');
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final v = snapshot.data![index];
              final isMotor = v['jenis_kendaraan'] == 'Motor';
              final hasStnk = v['foto_stnk'] != null &&
                  v['foto_stnk'].toString().isNotEmpty;
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.maroonSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isMotor
                                  ? Icons.motorcycle_rounded
                                  : Icons.directions_car_rounded,
                              color: AppTheme.maroon,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['plat_nomor'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20)),
                                Text(
                                    '${v['jenis_kendaraan']} | User ID: ${v['user_id']}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CC),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFD4A843)),
                            ),
                            child: const Text('PENDING',
                                style: TextStyle(
                                    color: Color(0xFF8B6914),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // STNK photo indicator
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasStnk ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasStnk
                                  ? Icons.image_rounded
                                  : Icons.image_not_supported_outlined,
                              size: 16,
                              color: hasStnk ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasStnk
                                    ? 'Foto STNK tersedia'
                                    : 'Foto STNK belum diupload',
                                style: TextStyle(
                                    color:
                                        hasStnk ? Colors.green : Colors.orange,
                                    fontSize: 12),
                              ),
                            ),
                            if (hasStnk)
                              TextButton(
                                onPressed: () => showStnkPhotoDialog(
                                    context, v['foto_stnk']),
                                child: const Text('Lihat',
                                    style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.maroon,
                                side: const BorderSide(color: AppTheme.maroon),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () =>
                                  _updateStatus(v['id'], 'ditolak'),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () =>
                                  _updateStatus(v['id'], 'disetujui'),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Setujui STNK'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── SEARCH MEMBER TAB ──────────────────────────────────────
class SearchMemberTab extends ConsumerStatefulWidget {
  const SearchMemberTab({super.key});

  @override
  ConsumerState<SearchMemberTab> createState() => _SearchMemberTabState();
}

class _SearchMemberTabState extends ConsumerState<SearchMemberTab> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;

  void _search() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioProvider).get('petugas/search',
          queryParameters: {'query': _searchController.text});
      setState(() => _results = res.data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toggleFlag(int userId, bool currentStatus) async {
    final reasonController = TextEditingController();
    bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentStatus ? 'Hapus Peringatan?' : 'Tambah Peringatan?'),
        content: currentStatus
            ? const Text(
                'Yakin ingin menghapus status peringatan pada user ini?')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'User ini akan ditandai pada setiap request akses masa depan.'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                          hintText:
                              'Alasan peringatan (misal: Sering parkir sembarang)')),
                ],
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: currentStatus ? Colors.green : Colors.orange),
            child: Text(currentStatus ? 'HAPUS' : 'SET FLAG'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(dioProvider).put('petugas/flag-user/$userId',
            queryParameters: {
              'is_flagged': !currentStatus,
              'reason': reasonController.text
            });
        _search(); // Refresh
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F4),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari NIM, Nama, atau Plat Nomor...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _searchController.clear()),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(color: AppTheme.maroon),
          Expanded(
            child: _results.isEmpty
                ? ModernEmptyState(
                    icon: Icons.person_search_rounded,
                    title: 'Cari Pengguna',
                    subtitle:
                        'Ketikkan NIM, Nama, atau Plat Nomor\nuntuk melihat detail member.',
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final u = _results[index];
                      final isFlagged = u['is_flagged'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isFlagged
                              ? Border.all(
                                  color: Colors.orange.withOpacity(0.5))
                              : null,
                          boxShadow: [],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isFlagged
                                  ? Colors.orange[100]
                                  : AppTheme.maroonSurface,
                              child: Icon(
                                  isFlagged
                                      ? Icons.warning_amber_rounded
                                      : Icons.person,
                                  color: isFlagged
                                      ? Colors.orange
                                      : AppTheme.maroon),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Text(u['nama'],
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16))),
                                      IconButton(
                                        icon: Icon(
                                            isFlagged
                                                ? Icons.flag
                                                : Icons.flag_outlined,
                                            color: isFlagged
                                                ? Colors.orange
                                                : Colors.grey,
                                            size: 20),
                                        onPressed: () =>
                                            _toggleFlag(u['id'], isFlagged),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('NIM: ${u['nim']}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13)),
                                  const SizedBox(height: 12),
                                  if ((u['vehicles'] as List).isNotEmpty) ...[
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: (u['vehicles'] as List)
                                          .map((v) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.maroon
                                                      .withOpacity(0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                        v['jenis'] == 'Motor'
                                                            ? Icons
                                                                .motorcycle_rounded
                                                            : Icons
                                                                .directions_car_rounded,
                                                        size: 14,
                                                        color: AppTheme.maroon),
                                                    const SizedBox(width: 4),
                                                    Text(v['plat'],
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppTheme
                                                                .maroon)),
                                                  ],
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ] else ...[
                                    Text('Belum ada kendaraan',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic)),
                                  ],
                                  if (isFlagged) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline,
                                              size: 14, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  'Ket: ${u['flag_reason']}',
                                                  style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Helpers ─────────────────────────────────────────
Widget _buildEmptyState(IconData icon, String message) {
  final parts = message.split('\n');
  return ListView(
    children: [
      const SizedBox(height: 80),
      ModernEmptyState(
        icon: icon,
        title: parts.isNotEmpty ? parts[0] : '',
        subtitle: parts.length > 1 ? parts.sublist(1).join('\n') : '',
      ),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
