import 'package:flutter/foundation.dart';

class AppConstants {
  // Local Development (Commented out for production)
  static const String baseUrl = 'http://localhost:8000/api/';
  static const String uploadBaseUrl = 'http://localhost:8000';
  static const String wsUrl = 'ws://localhost:8000/api/gate/monitor/live';
  static const String wsNotifUrl = 'ws://localhost:8000/api/gate/petugas/notifications';

  // Hosted/Production
  // static const String baseUrl = 'https://parkirkampus.my.id/api/';
  // static const String uploadBaseUrl = 'https://parkirkampus.my.id';
  // static const String wsUrl = 'wss://parkirkampus.my.id/api/gate/monitor/live';
  // static const String wsNotifUrl = 'wss://parkirkampus.my.id/api/gate/petugas/notifications';
}
