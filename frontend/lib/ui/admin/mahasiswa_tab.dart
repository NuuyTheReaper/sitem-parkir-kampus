import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';

class MahasiswaTab extends ConsumerWidget {
  const MahasiswaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mahasiswaList = ref.watch(mahasiswaListProvider);
    
    return Scaffold(
      body: mahasiswaList.when(
        data: (data) => ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final user = data[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['nama'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('${user['nim_npp']} - ${user['prodi_nama'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Semester: ${user['semester'] ?? '-'} | RFID: ${user['rfid_uid'] ?? '-'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                        onPressed: () => _showUserDialog(context, ref, user: user),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                        onPressed: () => _deleteUser(context, ref, user['id']),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUserDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? user}) async {
    final isEdit = user != null;
    final nimController = TextEditingController(text: user?['nim_npp']);
    final namaController = TextEditingController(text: user?['nama']);
    final rfidController = TextEditingController(text: user?['rfid_uid']);
    final passwordController = TextEditingController();
    
    int? selectedAngkatan = user?['angkatan'] ?? 2023;
    int? selectedProdiId = user?['prodi_id'];
    
    // Fetch Prodi list for dropdown
    final prodiList = await ref.read(adminProvider).getProdi();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blue, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Text(isEdit ? 'Edit Mahasiswa' : 'Tambah Mahasiswa', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('NIM', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(controller: nimController, decoration: InputDecoration(prefixIcon: const Icon(Icons.badge_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                    const SizedBox(height: 16),
                    const Text('Nama Lengkap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(controller: namaController, decoration: InputDecoration(prefixIcon: const Icon(Icons.person_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                    const SizedBox(height: 16),
                    const Text('RFID UID (Manual)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(controller: rfidController, decoration: InputDecoration(prefixIcon: const Icon(Icons.nfc_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
                    const SizedBox(height: 16),
                    const Text('Angkatan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedAngkatan,
                      items: [2023, 2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('Angkatan $y'))).toList(),
                      onChanged: (val) => setDialogState(() => selectedAngkatan = val),
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.date_range_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                    const SizedBox(height: 16),
                    const Text('Program Studi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: selectedProdiId,
                      items: prodiList.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['nama']))).toList(),
                      onChanged: (val) => setDialogState(() => selectedProdiId = val),
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.school_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                    const SizedBox(height: 16),
                    Text(isEdit ? 'New Password (opsional)' : 'Password', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController, 
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue),
                            onPressed: () async {
                              try {
                                final data = {
                                  if (nimController.text.isNotEmpty) 'nim_npp': nimController.text,
                                  if (namaController.text.isNotEmpty) 'nama': namaController.text,
                                  'prodi_id': selectedProdiId,
                                  'angkatan': selectedAngkatan,
                                  'rfid_uid': rfidController.text.isEmpty ? null : rfidController.text,
                                  if (passwordController.text.isNotEmpty) 'password': passwordController.text,
                                  'role': 'mahasiswa',
                                };
                                
                                if (!isEdit && passwordController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password wajib diisi untuk user baru')));
                                  return;
                                }

                                if (isEdit) {
                                  await ref.read(adminProvider).updateMahasiswa(user['id'], data);
                                } else {
                                  await ref.read(adminProvider).createMahasiswa(data);
                                }
                                
                                ref.invalidate(mahasiswaListProvider);
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ),
      );
    }
  }

  void _deleteUser(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Mahasiswa?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(adminProvider).deleteMahasiswa(id);
                ref.invalidate(mahasiswaListProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
