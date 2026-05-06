class AppConstants {
  // Use 10.0.2.2 for Android emulator testing against localhost
  // Or 127.0.0.1 for Web/iOS emulator
  static const String baseUrl = 'http://127.0.0.1:8000/api/';
  static const String uploadBaseUrl = 'http://127.0.0.1:8000';
  static const String wsUrl = 'ws://127.0.0.1:8000/api/gate/monitor/live';
  static const String wsNotifUrl = 'ws://127.0.0.1:8000/api/gate/petugas/notifications';
}
