import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import 'dart:html' as html;

class LogsTab extends ConsumerStatefulWidget {
  const LogsTab({super.key});
  @override
  ConsumerState<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<LogsTab> {
  String _filter = 'semua';

  Future<List<dynamic>> fetchLogs() async {
    final response = await ref.read(dioProvider).get('admin/reports');
    return response.data;
  }

  void _exportCsv() {
    // Open the CSV download URL in a new tab
    final url = '${AppConstants.baseUrl}admin/reports/export-csv';
    html.window.open(url, '_blank');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Mengunduh laporan CSV...'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Container(
          color: AppTheme.maroonSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.maroon),
              const SizedBox(width: 8),
              const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.maroon, fontSize: 13)),
              const SizedBox(width: 10),
              for (final f in ['semua', 'masuk', 'keluar'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f == 'semua' ? 'Semua' : f == 'masuk' ? '↑ Masuk' : '↓ Keluar'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppTheme.maroon,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: _filter == f ? Colors.white : AppTheme.maroon,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    side: const BorderSide(color: AppTheme.maroon),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              const Spacer(),
              // CSV Export button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.maroon,
                  side: const BorderSide(color: AppTheme.maroon),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _exportCsv,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.maroon),
                tooltip: 'Refresh',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        ),

        // Log list
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: fetchLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.maroon));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('Belum ada log aktivitas', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ],
                  ),
                );
              }

              final logs = snapshot.data!.where((l) {
                if (_filter == 'semua') return true;
                return l['jenis_aktivitas'] == _filter;
              }).toList();

              if (logs.isEmpty) {
                return Center(child: Text('Tidak ada log "$_filter".', style: const TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: logs.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isMasuk = log['jenis_aktivitas'] == 'masuk';
                  final isManual = log['status_akses'] == 'manual_petugas';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: isMasuk ? Colors.green[50] : AppTheme.maroonSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isMasuk ? Icons.login_rounded : Icons.logout_rounded,
                              color: isMasuk ? Colors.green : AppTheme.maroon,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${log['user_nama']} (${log['user_nim']})',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${log['vehicle_jenis'] ?? '-'} • ${log['vehicle_plat'] ?? '-'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  log['waktu']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isManual ? const Color(0xFFFFF3CC) : Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isManual ? const Color(0xFFD4A843) : Colors.blue.shade200),
                            ),
                            child: Text(
                              isManual ? 'MANUAL' : 'AUTO',
                              style: TextStyle(
                                color: isManual ? const Color(0xFF8B6914) : Colors.blue[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
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
        ),
      ],
    );
  }
}
