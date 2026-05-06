import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

final adminProvider = Provider<AdminService>((ref) {
  final dio = ref.watch(dioProvider);
  return AdminService(dio);
});

class AdminService {
  final Dio _dio;
  AdminService(this._dio);

  Future<List<dynamic>> getMahasiswa() async {
    final response = await _dio.get('admin/mahasiswa');
    return response.data as List<dynamic>;
  }

  Future<void> createMahasiswa(Map<String, dynamic> data) async {
    await _dio.post('admin/mahasiswa', data: data);
  }

  Future<void> updateMahasiswa(int id, Map<String, dynamic> data) async {
    await _dio.put('admin/mahasiswa/$id', data: data);
  }

  Future<void> deleteMahasiswa(int id) async {
    await _dio.delete('admin/mahasiswa/$id');
  }

  Future<List<dynamic>> getPetugas() async {
    final response = await _dio.get('admin/petugas');
    return response.data as List<dynamic>;
  }

  Future<void> createPetugas(Map<String, dynamic> data) async {
    await _dio.post('admin/petugas', data: data);
  }

  Future<void> updatePetugas(int id, Map<String, dynamic> data) async {
    await _dio.put('admin/petugas/$id', data: data);
  }

  Future<void> deletePetugas(int id) async {
    await _dio.delete('admin/petugas/$id');
  }

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('admin/dashboard-stats');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getActivityChart() async {
    final response = await _dio.get('admin/activity-chart');
    return response.data as List<dynamic>;
  }

  // Prodi CRUD
  Future<List<dynamic>> getProdi() async {
    final response = await _dio.get('admin/prodi');
    return response.data as List<dynamic>;
  }

  Future<void> createProdi(String nama) async {
    await _dio.post('admin/prodi', data: {'nama': nama});
  }

  Future<void> deleteProdi(int id) async {
    await _dio.delete('admin/prodi/$id');
  }

  Future<List<dynamic>> getReports() async {
    final response = await _dio.get('admin/reports');
    return response.data as List<dynamic>;
  }
}

final mahasiswaListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final adminService = ref.watch(adminProvider);
  return adminService.getMahasiswa();
});

final petugasListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final adminService = ref.watch(adminProvider);
  return adminService.getPetugas();
});
