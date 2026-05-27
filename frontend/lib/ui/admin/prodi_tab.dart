import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';
import '../../core/app_theme.dart';

class ProdiTab extends ConsumerStatefulWidget {
  const ProdiTab({super.key});

  @override
  ConsumerState<ProdiTab> createState() => _ProdiTabState();
}

class _ProdiTabState extends ConsumerState<ProdiTab> {
  String _searchQuery = '';

  Future<void> _showAddProdiDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                      color: AppTheme.maroonSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppTheme.maroon,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tambah Prodi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Nama Program Studi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.slate600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Teknik Informatika',
                  hintStyle: TextStyle(color: AppTheme.slate400, fontSize: 14),
                  prefixIcon: Icon(Icons.class_rounded,
                      color: AppTheme.slate400, size: 20),
                  filled: true,
                  fillColor: AppTheme.slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: AppTheme.slate600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.maroon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama prodi wajib diisi'),
                            ),
                          );
                          return;
                        }

                        try {
                          await ref.read(adminProvider).createProdi(name);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          setState(() {});
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal menambah prodi: $e')),
                          );
                        }
                      },
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and create
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.slate200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Cari program studi...',
                    hintStyle:
                        TextStyle(color: AppTheme.slate400, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppTheme.slate400, size: 20),
                    filled: true,
                    fillColor: AppTheme.slate50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Tambah Prodi',
                child: IconButton.filled(
                  onPressed: _showAddProdiDialog,
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Prodi List
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: ref.read(adminProvider).getProdi(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.maroon),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.slate400),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat data',
                        style:
                            TextStyle(color: AppTheme.slate600, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              var prodiList = snapshot.data ?? [];

              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                prodiList = prodiList.where((prodi) {
                  final nama = (prodi['nama'] ?? '').toString().toLowerCase();
                  return nama.contains(_searchQuery.toLowerCase());
                }).toList();
              }

              if (prodiList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.account_balance_outlined
                            : Icons.search_off_rounded,
                        size: 48,
                        color: AppTheme.slate400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Belum ada program studi'
                            : 'Tidak ditemukan',
                        style:
                            TextStyle(color: AppTheme.slate600, fontSize: 14),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddProdiDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Tambah Prodi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.maroon,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: AppTheme.maroon,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: prodiList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final prodi = prodiList[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.slate200),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.slate900.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.maroonSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_rounded,
                              color: AppTheme.maroon,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              prodi['nama'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.slate900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text('Hapus Prodi?'),
                                  content: Text(
                                    'Yakin ingin menghapus ${prodi['nama']}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Batal'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await ref
                                    .read(adminProvider)
                                    .deleteProdi(prodi['id']);
                                setState(() {});
                              }
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
