import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../core/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/api_client.dart';
import '../shared/parking_chart.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  final _broadcastController = TextEditingController();
  DateTime? _selectedExpiry;

  Future<void> _selectExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedExpiry =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _sendBroadcast({int? editId}) async {
    if (_broadcastController.text.isEmpty) return;
    try {
      final data = {
        'message': _broadcastController.text,
        'expires_at': _selectedExpiry?.toUtc().toIso8601String(),
      };

      if (editId != null) {
        await ref
            .read(dioProvider)
            .put('admin/announcements/$editId', data: data);
      } else {
        await ref.read(dioProvider).post('admin/broadcast', data: data);
      }

      _broadcastController.clear();
      setState(() => _selectedExpiry = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(editId != null
                ? '✓ Pengumuman diperbarui'
                : '✓ Pengumuman telah terkirim!'),
            backgroundColor: Colors.green));
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    try {
      await ref.read(dioProvider).delete('admin/announcements/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Pengumuman dihapus')));
        setState(() {});
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }

  void _showEditDialog(Map<String, dynamic> ann) {
    _broadcastController.text = ann['message'];
    _selectedExpiry =
        ann['expires_at'] != null ? DateTime.parse(ann['expires_at']) : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Pengumuman',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: _broadcastController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedExpiry ??
                          DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date == null) return;
                    if (!mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                          _selectedExpiry ?? DateTime.now()),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      _selectedExpiry = DateTime(date.year, date.month,
                          date.day, time.hour, time.minute);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(_selectedExpiry == null
                            ? 'Set Waktu Daluwarsa'
                            : 'Daluwarsa: ${_selectedExpiry!.toString().substring(0, 16)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _sendBroadcast(editId: ann['id']);
                          Navigator.pop(context);
                        },
                        child: const Text('Simpan'),
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
    return RefreshIndicator(
      color: AppTheme.maroon,
      onRefresh: () async => setState(() {}),
      child: FutureBuilder(
        future: Future.wait([
          ref.read(adminProvider).getDashboardStats(),
          ref.read(adminProvider).getActivityChart(),
          ref.read(dioProvider).get('admin/announcements'),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.maroon));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stats = snapshot.data![0] as Map<String, dynamic>;
          final chartData = snapshot.data![1] as List<dynamic>;
          final announcements = ((snapshot.data![2] as dynamic).data as List);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header greeting
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF5C0000),
                        Color(0xFF800000),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.maroon.withOpacity(0.2),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(IconlyLight.category,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dashboard Admin',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5)),
                                SizedBox(height: 2),
                                Text('Smart Campus Parking System',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF86EFAC),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Data Real-time',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats grid
                Row(
                  children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Total Mahasiswa',
                            value: stats['total_mahasiswa'].toString(),
                            icon: Icons.people_rounded,
                            color: AppTheme.maroon,
                            bgColor: AppTheme.maroonSurface)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _StatCard(
                          icon: Icons.admin_panel_settings_rounded,
                          label: 'Total Petugas',
                          value: '${stats['total_petugas']}',
                          color: Colors.blue,
                          bgColor: Colors.blue.withOpacity(0.08),
                          delayMs: 50,
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _StatCard(
                          icon: Icons.login_rounded,
                          label: 'Masuk Hari Ini',
                          value: '${stats['masuk_today'] ?? 0}',
                          color: Colors.green,
                          bgColor: Colors.green.withOpacity(0.08),
                          delayMs: 100,
                        )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _StatCard(
                          icon: Icons.output_rounded,
                          label: 'Keluar Hari Ini',
                          value: '${stats['keluar_today'] ?? 0}',
                          color: Colors.orange,
                          bgColor: Colors.orange.withOpacity(0.08),
                          delayMs: 150,
                        )),
                  ],
                ),
                const SizedBox(height: 28),

                // Chart
                Container(
                  decoration: AppTheme.modernCard,
                  padding: const EdgeInsets.all(20),
                  child: ParkingChart(chartData: chartData),
                ),
                const SizedBox(height: 24),

                // Broadcast Announcement Card
                Container(
                  decoration: AppTheme.modernCard,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppTheme.maroonSurface,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.campaign_rounded,
                                color: AppTheme.maroon, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kirim Pengumuman',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.maroonDark)),
                              Text('Broadcast ke semua mahasiswa',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _broadcastController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Tulis pesan pengumuman...',
                          filled: true,
                          fillColor: const Color(0xFFF8F4F2),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selectExpiry,
                              icon: const Icon(Icons.access_time_rounded, size: 18),
                              label: Text(
                                  _selectedExpiry == null
                                      ? 'Set Daluwarsa (Opsional)'
                                      : 'Exp: ${_selectedExpiry!.toString().substring(11, 16)}',
                                  style: const TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                            ),
                          ),
                          if (_selectedExpiry != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                                onPressed: () =>
                                    setState(() => _selectedExpiry = null),
                                icon: const Icon(Icons.close_rounded,
                                    size: 20, color: Colors.red)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.maroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _sendBroadcast(),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Kirim Sekarang',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Manage Announcements
                const Row(
                  children: [
                    Icon(IconlyLight.document,
                        size: 20, color: AppTheme.maroon),
                    SizedBox(width: 8),
                    Text('Kelola Pengumuman',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.maroonDark)),
                  ],
                ),
                const SizedBox(height: 12),
                if (announcements.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Belum ada pengumuman',
                              style: TextStyle(color: Colors.grey))))
                else
                  ...announcements
                      .map((ann) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: AppTheme.modernCard,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Icon(IconlyLight.profile,
                                          size: 14, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(ann['sender'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                    const Spacer(),
                                    IconButton(
                                        icon: const Icon(IconlyLight.edit,
                                            size: 18, color: Colors.blue),
                                        onPressed: () => _showEditDialog(ann)),
                                    IconButton(
                                        icon: const Icon(IconlyLight.delete,
                                            size: 18, color: Colors.red),
                                        onPressed: () =>
                                            _deleteAnnouncement(ann['id'])),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(ann['message'],
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        ann['created_at']
                                            .toString()
                                            .substring(0, 16)
                                            .replaceAll('T', ' '),
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                    if (ann['expires_at'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Row(
                                          children: [
                                            const Icon(
                                                IconlyLight.delete,
                                                size: 12,
                                                color: Colors.orange),
                                            const SizedBox(width: 4),
                                            Text(
                                                'Exp: ${ann['expires_at'].toString().substring(0, 16).replaceAll('T', ' ')}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.orange,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int delayMs;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.bgColor,
      this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slate900,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.slate500,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    )
        .animate(delay: delayMs.ms)
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}
