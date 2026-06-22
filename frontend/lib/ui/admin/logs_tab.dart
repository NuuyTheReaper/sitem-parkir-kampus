import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/platform_link.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LogsTab extends ConsumerStatefulWidget {
  const LogsTab({super.key});
  @override
  ConsumerState<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<LogsTab> {
  static const List<String> _typeFilters = ['semua', 'masuk', 'keluar'];
  static const List<String> _periodFilters = [
    'semua',
    'hari_ini',
    '7_hari',
    '30_hari',
  ];
  String _typeFilter = 'semua';
  String _periodFilter = 'semua';
  bool _isFilterExpanded = false;
  bool _isExporting = false;

  Future<List<dynamic>> fetchLogs() async {
    final response = await ref.read(dioProvider).get('admin/reports');
    return response.data;
  }

  void _exportCsv() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Menyiapkan laporan CSV...'),
          ],
        ),
        backgroundColor: AppTheme.maroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final response = await ref.read(dioProvider).get<List<int>>(
        'admin/reports/export-csv',
        queryParameters: {
          'jenis': _typeFilter,
          'periode': _periodFilter,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
        final filename = 'parking_logs_$timestamp.csv';
        downloadBytes(response.data!, filename);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.download_done_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Laporan CSV berhasil diunduh'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Gagal mengunduh CSV: ${e.toString()}')),
            ],
          ),
          backgroundColor: AppTheme.maroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _typeLabel(String filter) {
    return filter == 'semua'
        ? 'Semua'
        : filter == 'masuk'
            ? '↑ Masuk'
            : '↓ Keluar';
  }

  String _periodLabel(String filter) {
    return switch (filter) {
      'hari_ini' => 'Hari ini',
      '7_hari' => '7 hari',
      '30_hari' => '30 hari',
      _ => 'Semua',
    };
  }

  bool _matchesPeriod(dynamic rawTime) {
    if (_periodFilter == 'semua') return true;

    final timeText = rawTime?.toString();
    if (timeText == null || timeText.isEmpty) return false;

    final time = DateTime.tryParse(timeText)?.toLocal();
    if (time == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (_periodFilter) {
      'hari_ini' => today,
      '7_hari' => today.subtract(const Duration(days: 6)),
      '30_hari' => today.subtract(const Duration(days: 29)),
      _ => DateTime(0),
    };

    return !time.isBefore(start);
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false, // Menghilangkan ikon centang
      selectedColor: AppTheme.maroon,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.maroon,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: const BorderSide(color: AppTheme.maroon),
      backgroundColor: Colors.white,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12), // Sesuaikan padding agar lebih rapi tanpa centang
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  List<Widget> _buildTypeFilterChips() {
    return _typeFilters
        .map(
          (filter) => _buildFilterChip(
            label: _typeLabel(filter),
            selected: _typeFilter == filter,
            onSelected: () => setState(() => _typeFilter = filter),
          ),
        )
        .toList();
  }

  List<Widget> _buildPeriodFilterChips() {
    return _periodFilters
        .map(
          (filter) => _buildFilterChip(
            label: _periodLabel(filter),
            selected: _periodFilter == filter,
            onSelected: () => setState(() => _periodFilter = filter),
          ),
        )
        .toList();
  }

  Widget _buildFilterGroup(String label, List<Widget> chips) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.maroon,
            fontSize: 13,
          ),
        ),
        ...chips,
      ],
    );
  }

  Widget _buildExportButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.maroon,
        side: const BorderSide(color: AppTheme.maroon),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: _exportCsv,
      icon: const Icon(IconlyLight.download, size: 16),
      label: const Text(
        'CSV',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.maroonSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isFilterExpanded = !_isFilterExpanded),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: AppTheme.maroon,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Filter Laporan & Cetak',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.maroon,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isFilterExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.maroon,
                ),
              ],
            ),
          ),
          if (_isFilterExpanded) ...[
            const SizedBox(height: 16),
            _buildFilterGroup('Jenis', _buildTypeFilterChips()),
            const SizedBox(height: 12),
            _buildFilterGroup('Periode', _buildPeriodFilterChips()),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _exportCsv,
              icon: const Icon(IconlyLight.download, size: 18),
              label: const Text(
                'Cetak CSV Laporan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(refreshTriggerProvider);
    return Column(
      children: [
        _buildFilterBar(),

        // Log list
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: fetchLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppTheme.maroon));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconlyLight.document,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('Belum ada log aktivitas',
                          style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ],
                  ),
                );
              }

              final logs = snapshot.data!.where((l) {
                final matchesType = _typeFilter == 'semua' ||
                    l['jenis_aktivitas'] == _typeFilter;
                return matchesType && _matchesPeriod(l['waktu']);
              }).toList();

              if (logs.isEmpty) {
                return Center(
                    child: Text(
                        'Tidak ada log ${_typeLabel(_typeFilter).toLowerCase()} untuk periode ${_periodLabel(_periodFilter).toLowerCase()}.',
                        style: const TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: logs.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isMasuk = log['jenis_aktivitas'] == 'masuk';
                  final isManual = log['status_akses'] == 'manual_petugas' || log['status_akses'] == 'Emergency gate';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isMasuk
                                  ? Colors.green[50]
                                  : AppTheme.maroonSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isMasuk
                                  ? IconlyLight.login
                                  : IconlyLight.logout,
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${log['vehicle_jenis'] ?? '-'} • ${log['vehicle_plat'] ?? '-'}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  log['waktu']?.toString() ?? '-',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isManual
                                  ? const Color(0xFFFFF3CC)
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: isManual
                                      ? const Color(0xFFD4A843)
                                      : Colors.blue.shade200),
                            ),
                            child: Text(
                              isManual ? 'Emergency gate' : 'AUTO',
                              style: TextStyle(
                                color: isManual
                                    ? const Color(0xFF8B6914)
                                    : Colors.blue[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(delay: (index * 50).ms)
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
