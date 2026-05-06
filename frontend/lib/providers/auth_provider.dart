import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  final bool isLoading;
  final String? role;
  final String? error;
  final Map<String, dynamic>? user;

  AuthState({this.isLoading = false, this.role, this.error, this.user});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final nama = prefs.getString('user_nama');
    final nimNpp = prefs.getString('user_nim_npp');
    
    if (role != null) {
      state = AuthState(
        role: role, 
        user: {
          'nama': nama ?? '',
          'nim_npp': nimNpp ?? '',
        }
      );
    }
  }

  Future<bool> login(String nimNpp, String password) async {
    state = AuthState(isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      
      // Sending URL encoded form data (OAuth2 Password Bearer requirement)
      final response = await dio.post('auth/login', data: {
        'username': nimNpp,
        'password': password,
      }, options: Options(contentType: Headers.formUrlEncodedContentType));
      
      final token = response.data['access_token'];
      final role = response.data['role'];
      final nama = response.data['nama'];
      final nim = response.data['nim_npp'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('role', role);
      await prefs.setString('user_nama', nama);
      await prefs.setString('user_nim_npp', nim);
      
      state = AuthState(
        isLoading: false, 
        role: role, 
        user: {'nama': nama, 'nim_npp': nim}
      );
      return true;
    } on DioException catch (e) {
      state = AuthState(isLoading: false, error: e.response?.data['detail'] ?? e.message);
      return false;
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await ref.read(dioProvider).get('auth/me');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('role');
    await prefs.remove('user_nama');
    await prefs.remove('user_nim_npp');
    state = AuthState();
  }
}
