class AppConstants {
  static String get baseUrl {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return 'http://localhost:8000/api/';
    }
    return 'https://parkirkampus.my.id/api/';
  }

  static String get uploadBaseUrl {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return 'http://localhost:8000';
    }
    return 'https://parkirkampus.my.id';
  }

  static String get wsUrl {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return 'ws://localhost:8000/api/gate/monitor/live';
    }
    return 'wss://parkirkampus.my.id/api/gate/monitor/live';
  }

  static String get wsNotifUrl {
    if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
      return 'ws://localhost:8000/api/gate/petugas/notifications';
    }
    return 'wss://parkirkampus.my.id/api/gate/petugas/notifications';
  }
}
