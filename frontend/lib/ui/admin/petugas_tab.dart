import 'package:iconly/iconly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';

class PetugasTab extends ConsumerWidget {
  const PetugasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petugasList = ref.watch(petugasListProvider);

    return Scaffold(
      body: petugasList.when(
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
                boxShadow: [],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['nama'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('NPP: ${user['nim_npp']}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(IconlyLight.edit,
                            color: Colors.blue, size: 20),
                        onPressed: () =>
                            _showUserDialog(context, ref, user: user),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                      IconButton(
                        icon: const Icon(IconlyLight.delete,
                            color: Colors.red, size: 20),
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
        child: const Icon(IconlyLight.plus),
      ),
    );
  }

  void _showUserDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? user}) {
    final isEdit = user != null;
    final nimController = TextEditingController(text: user?['nim_npp']);
    final namaController = TextEditingController(text: user?['nama']);
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.orange, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Text(isEdit ? 'Edit Petugas' : 'Tambah Petugas',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('NPP',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                    controller: nimController,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.people_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 16),
                const Text('Nama Lengkap',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                    controller: namaController,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(IconlyLight.profile),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'New Password (opsional)' : 'Password',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(IconlyLight.lock),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16))),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Batal',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.orange),
                        onPressed: () async {
                          try {
                            final data = {
                              if (nimController.text.isNotEmpty)
                                'nim_npp': nimController.text,
                              if (namaController.text.isNotEmpty)
                                'nama': namaController.text,
                              if (passwordController.text.isNotEmpty)
                                'password': passwordController.text,
                              'role': 'petugas',
                            };

                            if (!isEdit && passwordController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Password wajib diisi untuk petugas baru')));
                              return;
                            }

                            if (isEdit) {
                              await ref
                                  .read(adminProvider)
                                  .updatePetugas(user['id'], data);
                            } else {
                              await ref.read(adminProvider).createPetugas(data);
                            }

                            ref.invalidate(petugasListProvider);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted)
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

  void _deleteUser(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Petugas?'),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(adminProvider).deletePetugas(id);
                ref.invalidate(petugasListProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
