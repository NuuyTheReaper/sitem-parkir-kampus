import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/api_client.dart';
import '../shared/filter_toggle.dart';

/// Users Tab - Unified management for Mahasiswa and Petugas
class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  String _selectedRole = 'mahasiswa'; // 'mahasiswa' or 'petugas'
  String _searchQuery = '';

  String get _roleLabel =>
      _selectedRole == 'mahasiswa' ? 'Mahasiswa' : 'Petugas';
  String get _identifierLabel => _selectedRole == 'mahasiswa' ? 'NIM' : 'NPP';

  Future<List<dynamic>> _fetchUsers() async {
    final endpoint =
        _selectedRole == 'mahasiswa' ? 'admin/mahasiswa' : 'admin/petugas';
    final response = await ref.read(dioProvider).get(endpoint);
    return response.data as List<dynamic>;
  }

  String _userIdentifier(Map<String, dynamic> user) {
    return (user['nim_npp'] ?? user['nim'] ?? user['nip'] ?? '-').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Role Selector & Search - Mobile First Design
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.slate200)),
          ),
          child: Column(
            children: [
              // Role Toggle
              FilterToggle(
                options: const [
                  FilterOption(
                    value: 'mahasiswa',
                    label: 'Mahasiswa',
                    icon: Icons.school_rounded,
                  ),
                  FilterOption(
                    value: 'petugas',
                    label: 'Petugas',
                    icon: Icons.badge_rounded,
                  ),
                ],
                selectedValue: _selectedRole,
                onChanged: (value) => setState(() {
                  _selectedRole = value;
                  _searchQuery = '';
                }),
              ),

              const SizedBox(height: 12),

              // Search and create
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Cari ${_roleLabel.toLowerCase()}...',
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
                    message: 'Tambah $_roleLabel',
                    child: IconButton.filled(
                      onPressed: _showUserFormDialog,
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
            ],
          ),
        ),

        // Users List
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _fetchUsers(),
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

              var users = snapshot.data ?? [];

              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                users = users.where((user) {
                  final nama = (user['nama'] ?? '').toString().toLowerCase();
                  final nim = _userIdentifier(user).toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return nama.contains(query) || nim.contains(query);
                }).toList();
              }

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.people_outline
                            : Icons.search_off_rounded,
                        size: 48,
                        color: AppTheme.slate400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Belum ada ${_roleLabel.toLowerCase()}'
                            : 'Tidak ditemukan',
                        style:
                            TextStyle(color: AppTheme.slate600, fontSize: 14),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showUserFormDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text('Tambah $_roleLabel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.maroon,
                            foregroundColor: Colors.white,
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
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildUserCard(user);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isMahasiswa = _selectedRole == 'mahasiswa';
    final identifier = _userIdentifier(user);
    final prodi = user['prodi_nama'];

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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.maroonSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMahasiswa ? Icons.school_rounded : Icons.badge_rounded,
              color: AppTheme.maroon,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['nama'] ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      identifier,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (prodi != null) ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.slate400,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          prodi,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Edit $_roleLabel',
                child: IconButton(
                  onPressed: () => _showUserFormDialog(user: user),
                  icon: const Icon(Icons.edit_rounded),
                  color: AppTheme.maroon,
                  iconSize: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => _showUserDetails(user),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppTheme.slate400,
                iconSize: 20,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDetails(Map<String, dynamic> user) async {
    final isMahasiswa = _selectedRole == 'mahasiswa';
    final identifier = _userIdentifier(user);

    final shouldEdit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
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
                      child: Icon(
                        isMahasiswa
                            ? Icons.school_rounded
                            : Icons.badge_rounded,
                        color: AppTheme.maroon,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['nama'] ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                          ),
                          Text(
                            identifier,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit $_roleLabel',
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.edit_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.maroonSurface,
                            foregroundColor: AppTheme.maroon,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.slate100,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildDetailRow(_identifierLabel, identifier),
                    if (user['prodi_nama'] != null)
                      _buildDetailRow('Program Studi', user['prodi_nama']),
                    if (user['angkatan'] != null)
                      _buildDetailRow('Angkatan', user['angkatan'].toString()),
                    if (user['semester'] != null)
                      _buildDetailRow('Semester', user['semester'].toString()),
                    if (user['rfid_uid'] != null)
                      _buildDetailRow('RFID UID', user['rfid_uid']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldEdit == true && mounted) {
      await _showUserFormDialog(user: user);
    }
  }

  Future<void> _showUserFormDialog({Map<String, dynamic>? user}) async {
    final isMahasiswa = _selectedRole == 'mahasiswa';
    List<dynamic> prodiList = [];

    if (isMahasiswa) {
      try {
        final response = await ref.read(dioProvider).get('admin/prodi');
        prodiList = response.data as List<dynamic>;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat prodi: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(
        role: _selectedRole,
        roleLabel: _roleLabel,
        identifierLabel: _identifierLabel,
        user: user,
        prodiList: prodiList,
        onSubmit: (data) async {
          final endpoint = isMahasiswa ? 'admin/mahasiswa' : 'admin/petugas';
          if (user != null) {
            await ref
                .read(dioProvider)
                .put('$endpoint/${user['id']}', data: data);
          } else {
            await ref.read(dioProvider).post(endpoint, data: data);
          }
        },
      ),
    );

    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_roleLabel berhasil ${user == null ? 'ditambahkan' : 'diperbarui'}',
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.slate900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

int? _asIntValue(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String _dialogUserIdentifier(Map<String, dynamic>? user) {
  return (user?['nim_npp'] ?? user?['nim'] ?? user?['nip'] ?? '').toString();
}

class _UserFormDialog extends StatefulWidget {
  final String role;
  final String roleLabel;
  final String identifierLabel;
  final Map<String, dynamic>? user;
  final List<dynamic> prodiList;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const _UserFormDialog({
    required this.role,
    required this.roleLabel,
    required this.identifierLabel,
    required this.user,
    required this.prodiList,
    required this.onSubmit,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  late final TextEditingController _identifierController;
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _rfidController;

  int? _selectedProdiId;
  late int _selectedAngkatan;
  bool _isSaving = false;
  String? _errorText;

  bool get _isMahasiswa => widget.role == 'mahasiswa';
  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _identifierController = TextEditingController(
      text: _dialogUserIdentifier(user),
    );
    _nameController = TextEditingController(
      text: (user?['nama'] ?? '').toString(),
    );
    _passwordController = TextEditingController();
    _rfidController = TextEditingController(
      text: (user?['rfid_uid'] ?? '').toString(),
    );

    _selectedProdiId = _asIntValue(user?['prodi_id']);
    if (_selectedProdiId != null &&
        !_validProdi
            .any((prodi) => _asIntValue(prodi['id']) == _selectedProdiId)) {
      _selectedProdiId = null;
    }
    _selectedAngkatan = _asIntValue(user?['angkatan']) ?? DateTime.now().year;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _rfidController.dispose();
    super.dispose();
  }

  List<dynamic> get _validProdi {
    return widget.prodiList
        .where((prodi) => _asIntValue(prodi['id']) != null)
        .toList(growable: false);
  }

  List<int> get _angkatanOptions {
    final currentYear = DateTime.now().year;
    final years = {
      for (var index = 0; index < 7; index++) currentYear - 4 + index,
      _selectedAngkatan,
    }.toList()
      ..sort();

    return years;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final identifier = _identifierController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || name.isEmpty) {
      setState(() {
        _errorText = '${widget.identifierLabel} dan nama wajib diisi';
      });
      return;
    }

    if (!_isEdit && password.isEmpty) {
      setState(() {
        _errorText = 'Password wajib diisi';
      });
      return;
    }

    final data = <String, dynamic>{
      'nim_npp': identifier,
      'nama': name,
      'role': widget.role,
    };

    if (!_isEdit || password.isNotEmpty) {
      data['password'] = password;
    }

    if (_isMahasiswa) {
      data.addAll({
        'prodi_id': _selectedProdiId,
        'angkatan': _selectedAngkatan,
        'rfid_uid': _rfidController.text.trim().isEmpty
            ? null
            : _rfidController.text.trim(),
      });
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSubmit(data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText =
            'Gagal ${_isEdit ? 'mengedit' : 'menambah'} ${widget.roleLabel}: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                    child: Icon(
                      _isMahasiswa ? Icons.school_rounded : Icons.badge_rounded,
                      color: AppTheme.maroon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_isEdit ? 'Edit' : 'Tambah'} ${widget.roleLabel}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFormField(
                controller: _identifierController,
                label: widget.identifierLabel,
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 14),
              _buildFormField(
                controller: _nameController,
                label: 'Nama Lengkap',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 14),
              _buildFormField(
                controller: _passwordController,
                label: _isEdit ? 'Password baru (opsional)' : 'Password',
                icon: Icons.lock_rounded,
                obscureText: true,
              ),
              if (_isMahasiswa) ...[
                const SizedBox(height: 14),
                _buildAngkatanSelector(),
                const SizedBox(height: 14),
                _buildProdiSelector(),
                const SizedBox(height: 14),
                _buildFormField(
                  controller: _rfidController,
                  label: 'RFID UID (opsional)',
                  icon: Icons.nfc_rounded,
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan',
                              style: TextStyle(fontWeight: FontWeight.w700),
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
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _buildSelectionShell({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.slate300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.slate500),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.slate600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _selectableOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.maroonSurface : AppTheme.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.maroon : AppTheme.slate200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.maroon : AppTheme.slate700,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.maroon,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngkatanSelector() {
    return _buildSelectionShell(
      label: 'Angkatan',
      icon: Icons.date_range_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _angkatanOptions.map((year) {
          final selected = year == _selectedAngkatan;
          return GestureDetector(
            onTap: () => setState(() => _selectedAngkatan = year),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.maroon : AppTheme.slate50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppTheme.maroon : AppTheme.slate200,
                ),
              ),
              child: Text(
                '$year',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.slate700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProdiSelector() {
    final options = <Widget>[
      _selectableOption(
        label: 'Belum pilih prodi',
        selected: _selectedProdiId == null,
        onTap: () => setState(() => _selectedProdiId = null),
      ),
      for (final prodi in _validProdi) ...[
        const SizedBox(height: 8),
        _selectableOption(
          label: (prodi['nama'] ?? '-').toString(),
          selected: _selectedProdiId == _asIntValue(prodi['id']),
          onTap: () =>
              setState(() => _selectedProdiId = _asIntValue(prodi['id'])),
        ),
      ],
    ];

    return _buildSelectionShell(
      label: 'Program Studi',
      icon: Icons.account_balance_rounded,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          child: Column(children: options),
        ),
      ),
    );
  }
}
