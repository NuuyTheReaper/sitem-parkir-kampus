import 'package:flutter/foundation.dart';

class AppConstants {
  static const String baseUrl = kDebugMode
      ? 'http://127.0.0.1:8000/api/'
      : 'https://parkirkampus.my.id/api/';
  static const String uploadBaseUrl = kDebugMode
      ? 'http://127.0.0.1:8000'
      : 'https://parkirkampus.my.id';
  static const String wsUrl = kDebugMode
      ? 'ws://127.0.0.1:8000/api/gate/monitor/live'
      : 'wss://parkirkampus.my.id/api/gate/monitor/live';
  static const String wsNotifUrl = kDebugMode
      ? 'ws://127.0.0.1:8000/api/gate/petugas/notifications'
      : 'wss://parkirkampus.my.id/api/gate/petugas/notifications';
}
