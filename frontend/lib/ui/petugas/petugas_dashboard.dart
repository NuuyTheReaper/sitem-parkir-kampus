import 'package:iconly/iconly.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../shared/profile_tab.dart';
import '../shared/parking_chart.dart';
import '../shared/modern_components.dart';
import '../shared/web_mjpeg_viewer.dart';
import '../shared/web_camera_viewer.dart';
import '../shared/app_header.dart';
import '../shared/app_navbar.dart';
import '../shared/filter_toggle.dart';

// Provider to track pending request count for badge
final pendingCountProvider = StateProvider<int>((ref) => 0);

// Provider for activity chart data
final activityChartProvider = FutureProvider<List<dynamic>>((ref) async {
ref.watch(refreshTriggerProvider); // Auto-refresh when triggered
final res = await ref.read(dioProvider).get('petugas/activity-chart');
return res.data as List<dynamic>;
});

class PetugasDashboard extends ConsumerStatefulWidget {
const PetugasDashboard({super.key});

@override
ConsumerState<PetugasDashboard> createState() => _PetugasDashboardState();
}

class _PetugasDashboardState extends ConsumerState<PetugasDashboard> {
int _currentIndex = 0;
WebSocketChannel? _notifChannel;

@override
void initState() {
super.initState();
_refreshBadge();
_connectNotificationWS();
}

void _connectNotificationWS() {
try {
_notifChannel =
WebSocketChannel.connect(Uri.parse(AppConstants.wsNotifUrl));

// Catch ready future errors to prevent uncaught zone exception
_notifChannel!.ready.catchError((err) {
debugPrint('WS Notif Connection Error: $err');
});

_notifChannel!.stream.listen((message) {
try {
final decoded = jsonDecode(message);
if (decoded['type'] == 'new_access_request') {
// Trigger global refresh for all tabs
ref.read(refreshTriggerProvider.notifier).state++;

// Increment badge immediately
ref.read(pendingCountProvider.notifier).state++;
// Show snackbar notification
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Row(
children: [
const Icon(Icons.notifications_active,
color: Colors.white, size: 20),
const SizedBox(width: 8),
Expanded(
child: Text(
'📥 Permintaan baru dari ${decoded['user_nama']} (${decoded['jenis_aktivitas']})',
style: const TextStyle(fontWeight: FontWeight.w600),
),
),
],
),
backgroundColor: AppTheme.maroon,
behavior: SnackBarBehavior.floating,
duration: const Duration(seconds: 4),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10)),
action: SnackBarAction(
label: 'LIHAT',
textColor: Colors.white,
onPressed: () => setState(() => _currentIndex = 1),
),
),
);
}
}
} catch (e) {
debugPrint('WS Notif Error: $e');
}
}, onError: (_) {
// Reconnect after error
Future.delayed(const Duration(seconds: 5), _connectNotificationWS);
});
} catch (_) {}
}

@override
void dispose() {
_notifChannel?.sink.close();
super.dispose();
}

Future<void> _refreshBadge() async {
try {
final res =
await ref.read(dioProvider).get('petugas/access-requests/pending');
final count = (res.data as List).length;
ref.read(pendingCountProvider.notifier).state = count;
} catch (_) {}
}

Widget _wrapResponsive(Widget child, bool isDesktop) {
if (!isDesktop) return child;
return Center(
child: ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 850),
child: child,
),
);
}

Widget _buildDesktopSidebar(BuildContext context, List<NavBarItem> items) {
return Container(
width: 260,
color: Colors.white,
padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Padding(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
child: Text(
'MENU UTAMA',
style: TextStyle(
fontSize: 11,
fontWeight: FontWeight.w800,
color: AppTheme.slate400,
letterSpacing: 1.5,
),
),
),
const SizedBox(height: 8),
Expanded(
child: ListView.separated(
itemCount: items.length,
separatorBuilder: (context, index) => const SizedBox(height: 8),
itemBuilder: (context, index) {
final item = items[index];
final isSelected = _currentIndex == index;
return InkWell(
onTap: () {
setState(() => _currentIndex = index);
if (index == 1) _refreshBadge();
},
borderRadius: BorderRadius.circular(12),
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 16, vertical: 12),
decoration: BoxDecoration(
color: isSelected
? AppTheme.maroon.withOpacity(0.08)
: Colors.transparent,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: isSelected
? AppTheme.maroon.withOpacity(0.12)
: Colors.transparent,
),
),
child: Row(
children: [
Icon(
item.icon,
color: isSelected ? AppTheme.maroon : AppTheme.slate500,
size: 22,
),
const SizedBox(width: 14),
Expanded(
child: Text(
item.label,
style: TextStyle(
color: isSelected
? AppTheme.maroon
: AppTheme.slate700,
fontWeight: isSelected
? FontWeight.w700
: FontWeight.w500,
fontSize: 14,
),
),
),
if (item.badgeCount != null && item.badgeCount! > 0)
Container(
padding: const EdgeInsets.symmetric(
horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: AppTheme.maroon,
borderRadius: BorderRadius.circular(10),
),
child: Text(
'${item.badgeCount}',
style: const TextStyle(
color: Colors.white,
fontSize: 10,
fontWeight: FontWeight.bold,
),
),
),
],
),
),
);
},
),
),
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: AppTheme.slate50,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: AppTheme.slate100),
),
child: Row(
children: [
CircleAvatar(
radius: 18,
backgroundColor: AppTheme.maroon.withOpacity(0.1),
child: const Icon(Icons.person, color: AppTheme.maroon, size: 18),
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisSize: MainAxisSize.min,
children: const [
Text(
'Petugas Parkir',
style: TextStyle(
fontSize: 13,
fontWeight: FontWeight.bold,
color: AppTheme.slate800,
),
),
Text(
'Command Center',
style: TextStyle(
fontSize: 10,
color: AppTheme.slate400,
),
),
],
),
),
],
),
),
],
),
);
}

@override
Widget build(BuildContext context) {
final pendingCount = ref.watch(pendingCountProvider);
final size = MediaQuery.of(context).size;
final isDesktop = size.width >= 900;

final navItems = [
const NavBarItem(label: 'Monitor', icon: Icons.monitor_rounded),
NavBarItem(
label: 'Permintaan',
icon: Icons.pending_actions_rounded,
badgeCount: pendingCount,
),
const NavBarItem(label: 'Cari', icon: Icons.person_search_rounded),
const NavBarItem(label: 'Profil', icon: Icons.account_circle_rounded),
];

final Widget bodyContent = IndexedStack(
index: _currentIndex,
children: [
const LiveMonitorTab(),
_wrapResponsive(PermintaanTabWithFilter(onCountChanged: _refreshBadge), isDesktop),
_wrapResponsive(const SearchMemberTab(), isDesktop),
_wrapResponsive(const ProfileTab(), isDesktop),
],
);

final appBarWidget = AppHeader(
title: 'Command Center',
subtitle: 'Smart Parking System',
actions: [
Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.1),
borderRadius: BorderRadius.circular(10),
),
child: Row(
children: [
Container(
width: 6,
height: 6,
decoration: const BoxDecoration(
color: Colors.greenAccent,
shape: BoxShape.circle,
),
),
const SizedBox(width: 6),
const Text(
'ONLINE',
style: TextStyle(
color: Colors.greenAccent,
fontSize: 10,
fontWeight: FontWeight.w700,
letterSpacing: 1,
),
),
],
),
),
const SizedBox(width: 8),
IconButton(
icon: const Icon(Icons.refresh_rounded,
color: Colors.white70, size: 22),
onPressed: () {
_refreshBadge();
ref.read(refreshTriggerProvider.notifier).state++;
},
),
],
);

if (isDesktop) {
return Scaffold(
appBar: appBarWidget,
body: Row(
children: [
_buildDesktopSidebar(context, navItems),
const VerticalDivider(width: 1, thickness: 1),
Expanded(child: bodyContent),
],
),
);
}

return Scaffold(
appBar: appBarWidget,
body: bodyContent,
bottomNavigationBar: AppNavBar(
currentIndex: _currentIndex,
onTap: (index) {
setState(() => _currentIndex = index);
if (index == 1) _refreshBadge();
},
items: navItems,
),
);
}
}

class SessionStatsSummary extends ConsumerWidget {
const SessionStatsSummary({super.key});

@override
Widget build(BuildContext context, WidgetRef ref) {
ref.watch(refreshTriggerProvider); // Rebuild & refetch on global refresh
final size = MediaQuery.of(context).size;
final isDesktop = size.width >= 900;

return FutureBuilder(
future: Future.wait([
ref.read(dioProvider).get('petugas/session-stats'),
ref.read(dioProvider).get('gate/stats/capacity'),
]),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
if (isDesktop) {
return Column(
children: List.generate(
3,
(_) => Container(
height: 90,
margin: const EdgeInsets.symmetric(vertical: 6),
decoration: BoxDecoration(
color: AppTheme.slate100,
borderRadius: BorderRadius.circular(16)),
),
),
);
}
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Row(
children: List.generate(
3,
(_) => Expanded(
child: Container(
height: 80,
margin: const EdgeInsets.symmetric(horizontal: 4),
decoration: BoxDecoration(
color: AppTheme.slate100,
borderRadius: BorderRadius.circular(16)),
),
))),
);
}
final stats = ((snapshot.data?[0] as dynamic)?.data ??
{"handled_count": 0, "pending_stnk": 0}) as Map<String, dynamic>;
final capData = ((snapshot.data?[1] as dynamic)?.data ??
{"parked": 0, "total": 100}) as Map<String, dynamic>;
final parked = (capData['parked'] ?? 0) as int;
final total = (capData['total'] ?? 100) as int;

if (isDesktop) {
return Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
_StatCard(
icon: Icons.directions_car_filled_rounded,
label: 'Terisi',
value: '$parked/$total',
color: AppTheme.teal,
progress: total > 0 ? parked / total : 0,
delayMs: 0,
isExpanded: false,
),
const SizedBox(height: 12),
_StatCard(
icon: Icons.check_circle_rounded,
label: 'Selesai',
value: '${stats['handled_count']}',
color: AppTheme.emerald,
delayMs: 100,
isExpanded: false,
),
const SizedBox(height: 12),
_StatCard(
icon: Icons.assignment_late_rounded,
label: 'STNK',
value: '${stats['pending_stnk'] ?? stats['stnk_pending_count'] ?? 0}',
color: Colors.orange,
delayMs: 200,
isExpanded: false,
),
],
);
}

return Padding(
padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
child: IntrinsicHeight(
child: Row(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
_StatCard(
icon: Icons.directions_car_filled_rounded,
label: 'Terisi',
value: '$parked/$total',
color: AppTheme.teal,
progress: total > 0 ? parked / total : 0,
delayMs: 0,
),
const SizedBox(width: 10),
_StatCard(
icon: Icons.check_circle_rounded,
label: 'Selesai',
value: '${stats['handled_count']}',
color: AppTheme.emerald,
delayMs: 100,
),
const SizedBox(width: 10),
_StatCard(
icon: Icons.assignment_late_rounded,
label: 'STNK',
value: '${stats['pending_stnk'] ?? stats['stnk_pending_count'] ?? 0}',
color: Colors.orange,
delayMs: 200,
),
],
),
),
);
},
);
}
}

class _StatCard extends StatelessWidget {
final IconData icon;
final String label;
final String value;
final Color color;
final double? progress;
final int delayMs;
final bool isExpanded;

const _StatCard({
required this.label,
required this.value,
required this.icon,
required this.color,
this.progress,
this.delayMs = 0,
this.isExpanded = true,
});

@override
Widget build(BuildContext context) {
Widget cardContent = Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: AppTheme.slate200),
boxShadow: [
BoxShadow(
color: AppTheme.slate900.withOpacity(0.02),
blurRadius: 4,
offset: const Offset(0, 1),
),
],
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
mainAxisAlignment: MainAxisAlignment.center,
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: color.withOpacity(0.08),
borderRadius: BorderRadius.circular(10),
),
child: Icon(icon, size: 18, color: color),
),
const SizedBox(height: 8),
Text(
label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
fontSize: 11,
color: AppTheme.slate500,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 4),
FittedBox(
fit: BoxFit.scaleDown,
alignment: Alignment.centerLeft,
child: Text(
value,
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.w800,
color: AppTheme.slate900,
letterSpacing: -0.5,
),
),
),
if (progress != null) ...[
const SizedBox(height: 10),
ClipRRect(
borderRadius: BorderRadius.circular(4),
child: LinearProgressIndicator(
value: progress!,
minHeight: 4,
backgroundColor: color.withOpacity(0.1),
color: color,
),
),
],
],
),
);

if (isExpanded) {
cardContent = Expanded(child: cardContent);
}

return cardContent.animate(delay: delayMs.ms).fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
}
}

// ── LIVE MONITOR TAB ───────────────────────────────────────
class LiveMonitorTab extends ConsumerStatefulWidget {
const LiveMonitorTab({super.key});

@override
ConsumerState<LiveMonitorTab> createState() => _LiveMonitorTabState();
}

class _LiveMonitorTabState extends ConsumerState<LiveMonitorTab> {
WebSocketChannel? channel;
final List<Map<String, dynamic>> logs = [];
String? _cameraUrl;
bool _showCamera = false;
bool _isEmergencyExpanded = false;
String _cameraType = 'ip_camera';
final _cameraController = WebCameraController();

@override
void initState() {
super.initState();
_loadCameraSettings();
try {
channel = WebSocketChannel.connect(Uri.parse(AppConstants.wsUrl));

// Catch ready future errors to prevent uncaught zone exception
channel!.ready.catchError((err) {
debugPrint('WS Live Monitor Connection Error: $err');
});

channel!.stream.listen((message) {
try {
final decoded = jsonDecode(message);

// Auto capture trigger for webcam testing flow
if (decoded['type'] == 'trigger_capture') {
final rfidUid = decoded['rfid_uid'] ?? '';
final gateId = decoded['gate_id'] ?? 'GATE_DEFAULT';
final gateType = decoded['gate_type'] ?? 'masuk';
_autoCaptureAndUpload(rfidUid, gateId, gateType);
return; // Skip adding trigger control message to UI activity list
}

if (mounted) {
setState(() {
logs.insert(0, decoded);
while (logs.length > 3) {
logs.removeLast();
}
});
// Trigger global refresh so capacity/chart update too
ref.read(refreshTriggerProvider.notifier).state++;
}
} catch (e) {
debugPrint('WS Live Monitor Error: $e');
}
}, onError: (_) {});
} catch (_) {}
}

Future<void> _loadCameraSettings() async {
try {
final prefs = await SharedPreferences.getInstance();
setState(() {
String savedType = prefs.getString('petugas_camera_type') ?? 'ip_camera';
if (savedType != 'ip_camera' && savedType != 'device_camera') {
savedType = 'ip_camera';
}
_cameraType = savedType;
_cameraUrl = prefs.getString('petugas_camera_url');
_showCamera = prefs.getBool('petugas_show_camera') ?? false;
});
} catch (e) {
debugPrint('Error loading camera settings: $e');
}
}

Future<void> _saveCameraSettings() async {
try {
final prefs = await SharedPreferences.getInstance();
await prefs.setString('petugas_camera_type', _cameraType);
if (_cameraUrl != null) {
await prefs.setString('petugas_camera_url', _cameraUrl!);
} else {
await prefs.remove('petugas_camera_url');
}
await prefs.setBool('petugas_show_camera', _showCamera);
} catch (e) {
debugPrint('Error saving camera settings: $e');
}
}

@override
void dispose() {
channel?.sink.close();
super.dispose();
}

void _showCameraDialog() {
String localCameraType = _cameraType;
if (localCameraType != 'ip_camera' && localCameraType != 'device_camera') {
localCameraType = 'ip_camera';
}

final urlCtrl = TextEditingController(
text: (localCameraType == 'ip_camera') ? (_cameraUrl ?? '') : '',
);

showDialog(
context: context,
builder: (ctx) => StatefulBuilder(
builder: (context, setStateDialog) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: Row(
children: const [
Icon(IconlyLight.camera, color: AppTheme.maroon),
SizedBox(width: 8),
Expanded(
child: Text('Koneksi Kamera'),
),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Tipe Kamera',
style: TextStyle(
fontWeight: FontWeight.w700,
fontSize: 13,
color: AppTheme.slate700,
),
),
const SizedBox(height: 8),
DropdownButtonFormField<String>(
value: localCameraType,
isExpanded: true,
items: const [
DropdownMenuItem(
value: 'ip_camera',
child: Text('IP Camera (MJPEG Stream)'),
),
DropdownMenuItem(
value: 'device_camera',
child: Text('Camera Device (Webcam)'),
),
],
onChanged: (val) {
if (val != null) {
setStateDialog(() {
localCameraType = val;
});
}
},
decoration: InputDecoration(
prefixIcon: const Icon(IconlyLight.setting, size: 20),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
const SizedBox(height: 16),
if (localCameraType == 'ip_camera') ...[
TextField(
controller: urlCtrl,
decoration: InputDecoration(
labelText: 'URL Stream Kamera',
hintText: 'http://192.168.x.x:81/stream',
prefixIcon: const Icon(Icons.link_rounded, size: 20),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: Colors.blue[50],
borderRadius: BorderRadius.circular(8),
),
child: const Row(
children: [
Icon(Icons.info_outline, size: 14, color: Colors.blue),
SizedBox(width: 8),
Expanded(
child: Text(
'Masukkan URL MJPEG stream dari ESP32-CAM atau IP Camera Anda.',
style: TextStyle(fontSize: 11, color: Colors.blue),
),
),
],
),
),
] else if (localCameraType == 'device_camera') ...[
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: AppTheme.emerald.withOpacity(0.08),
borderRadius: BorderRadius.circular(10),
border: Border.all(color: AppTheme.emerald.withOpacity(0.2)),
),
child: Row(
children: [
const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.emerald),
const SizedBox(width: 8),
Expanded(
child: Text(
'Akan menggunakan webcam lokal pada perangkat Anda. Izinkan akses kamera saat diminta.',
style: TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w500),
),
),
],
),
),
],
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
style: TextButton.styleFrom(foregroundColor: AppTheme.slate500),
child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
),
if (_cameraUrl != null || _showCamera)
TextButton(
onPressed: () {
setState(() {
_cameraUrl = null;
_showCamera = false;
});
_saveCameraSettings();
Navigator.pop(ctx);
},
child: const Text('Putuskan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
),
ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.maroon,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
onPressed: () {
setState(() {
_cameraType = localCameraType;
if (_cameraType == 'ip_camera') {
_cameraUrl = urlCtrl.text.isNotEmpty ? urlCtrl.text : null;
_showCamera = _cameraUrl != null;
} else {
_cameraUrl = 'device_camera';
_showCamera = true;
}
});
_saveCameraSettings();
Navigator.pop(ctx);
},
icon: const Icon(Icons.link_rounded, color: Colors.white, size: 18),
label: const Text('Hubungkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
),
],
),
),
);
}

Future<void> _captureAndScanDeviceCamera() async {
final rfidCtrl = TextEditingController(text: 'RFID_BUDI_123');
VoidCallback? dialogListener;
rfidCtrl.addListener(() {
if (dialogListener != null) {
dialogListener!();
}
});

try {
final bytes = await _cameraController.capture();
if (bytes == null) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Gagal mengambil gambar dari webcam. Pastikan kamera aktif dan berikan izin.'),
backgroundColor: Colors.red,
),
);
}
return;
}

// Show dialog to choose RFID card & Gate Type
String gateType = 'masuk';
String gateId = 'GATE_MASUK_1';

if (!mounted) return;

bool confirmed = await showDialog<bool>(
context: context,
builder: (ctx) => StatefulBuilder(
builder: (context, setStateDialog) {
dialogListener = () {
if (mounted) setStateDialog(() {});
};
return AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: Row(
children: const [
Icon(IconlyLight.scan, color: AppTheme.maroon),
SizedBox(width: 8),
Expanded(
child: Text('Scan Plat via Webcam'),
),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Center(
child: ClipRRect(
borderRadius: BorderRadius.circular(8),
child: Image.memory(
Uint8List.fromList(bytes),
height: 120,
width: 180,
fit: BoxFit.cover,
),
),
),
const SizedBox(height: 16),
const Text('Pilih RFID (Simulasi Kartu):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
const SizedBox(height: 8),
DropdownButtonFormField<String>(
value: (rfidCtrl.text == 'RFID_BUDI_123' || rfidCtrl.text == 'RFID_SITI_456') ? rfidCtrl.text : 'custom',
isExpanded: true,
items: const [
DropdownMenuItem(value: 'RFID_BUDI_123', child: Text('Budi Santoso (RFID_BUDI_123)')),
DropdownMenuItem(value: 'RFID_SITI_456', child: Text('Siti Aminah (RFID_SITI_456)')),
DropdownMenuItem(value: 'custom', child: Text('Manual / Custom UID')),
],
onChanged: (val) {
if (val != null) {
setStateDialog(() {
if (val != 'custom') {
rfidCtrl.text = val;
} else {
rfidCtrl.text = '';
}
});
}
},
decoration: InputDecoration(
prefixIcon: const Icon(Icons.nfc_rounded, size: 20),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
const SizedBox(height: 12),
TextField(
controller: rfidCtrl,
decoration: InputDecoration(
labelText: 'UID RFID',
hintText: 'Masukkan UID RFID',
prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.maroon, width: 1.5),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
const SizedBox(height: 16),
const Text('Gerbang:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
const SizedBox(height: 6),
Row(
children: [
Expanded(
child: RadioListTile<String>(
title: const Text('Masuk', style: TextStyle(fontSize: 12)),
value: 'masuk',
groupValue: gateType,
activeColor: AppTheme.maroon,
onChanged: (val) {
setStateDialog(() {
gateType = val!;
gateId = 'GATE_MASUK_1';
});
},
contentPadding: EdgeInsets.zero,
),
),
Expanded(
child: RadioListTile<String>(
title: const Text('Keluar', style: TextStyle(fontSize: 12)),
value: 'keluar',
groupValue: gateType,
activeColor: AppTheme.maroon,
onChanged: (val) {
setStateDialog(() {
gateType = val!;
gateId = 'GATE_KELUAR_1';
});
},
contentPadding: EdgeInsets.zero,
),
),
],
),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
style: TextButton.styleFrom(foregroundColor: AppTheme.slate500),
child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: AppTheme.maroon,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
onPressed: () {
if (rfidCtrl.text.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('UID RFID tidak boleh kosong')),
);
return;
}
Navigator.pop(ctx, true);
},
child: const Text('Upload & Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
),
],
);
},
),
) ?? false;

if (confirmed && mounted) {
// Show loading dialog
showDialog(
context: context,
barrierDismissible: false,
builder: (ctx) => const Center(
child: Card(
child: Padding(
padding: EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
CircularProgressIndicator(color: AppTheme.maroon),
SizedBox(height: 16),
Text('Mengirim foto & memvalidasi...', style: TextStyle(fontWeight: FontWeight.bold)),
],
),
),
),
),
);

try {
final dio = ref.read(dioProvider);
final mimeSubtype = 'jpeg';

// Create form data
final formData = FormData.fromMap({
'rfid_uid': rfidCtrl.text,
'gate_type': gateType,
'gate_id': gateId,
'file': MultipartFile.fromBytes(
bytes,
filename: 'webcam_capture.jpg',
contentType: MediaType('image', mimeSubtype),
),
});

final response = await dio.post(
'gate/upload-validate',
data: formData,
);

if (mounted) {
Navigator.pop(context); // Pop loading dialog

final action = response.data['action'] ?? 'keep_closed';
final message = response.data['message'] ?? '';
final detail = response.data['validation_detail'] ?? '';
final studentName = response.data['student_name'];
final plateNumber = response.data['plate_number'];

showDialog(
context: context,
builder: (ctx) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: Row(
children: [
Icon(
action == 'open_gate' ? Icons.check_circle_rounded : Icons.cancel_rounded,
color: action == 'open_gate' ? Colors.green : Colors.red,
size: 28,
),
const SizedBox(width: 8),
Expanded(
child: Text(
action == 'open_gate' ? 'Validasi Berhasil' : 'Akses Ditolak',
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
),
],
),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (studentName != null) ...[
Text('Mahasiswa: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
const SizedBox(height: 4),
],
if (plateNumber != null) ...[
Text('Plat: $plateNumber', style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16)),
const SizedBox(height: 8),
],
Text('Pesan: $message'),
const SizedBox(height: 4),
Text('Detail: $detail', style: const TextStyle(color: Colors.grey, fontSize: 11)),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('OK'),
),
],
),
);

// Trigger global refresh
ref.read(refreshTriggerProvider.notifier).state++;
}
} catch (e) {
if (mounted) {
Navigator.pop(context); // Pop loading dialog
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Gagal: $e'),
backgroundColor: AppTheme.maroon,
),
);
}
}
}
} catch (e) {
debugPrint('Error capturing frame: $e');
} finally {
rfidCtrl.dispose();
}
}

    Future<void> _autoCaptureAndUpload(String rfidUid, String gateId, String gateType) async {
      // Tampilkan notifikasi awal di UI bahwa RFID terdeteksi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('RFID Terdeteksi ($rfidUid). Memotret webcam...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Hanya memotret jika kamera aktif dan menggunakan tipe device_camera (webcam)
      if (!_showCamera || _cameraType != 'device_camera' || _cameraController == null) {
        debugPrint('[AutoCapture] Kamera tidak aktif atau bukan device_camera');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-Capture Gagal: Webcam tidak aktif/belum terhubung!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
      try {
        debugPrint('[AutoCapture] Menangkap frame webcam secara otomatis untuk RFID $rfidUid...');
        final bytes = await _cameraController!.capture();
        if (bytes == null) {
          debugPrint('[AutoCapture] Gagal mendapatkan bytes gambar');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Auto-Capture Gagal: Tidak dapat menangkap gambar webcam.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        final dio = ref.read(dioProvider);
        final mimeSubtype = 'jpeg';
        
        final formData = FormData.fromMap({
          'rfid_uid': rfidUid,
          'gate_id': gateId,
          'gate_type': gateType,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: 'webcam_auto_capture.jpg',
            contentType: MediaType('image', mimeSubtype),
          ),
        });
        
        debugPrint('[AutoCapture] Mengunggah frame hasil tangkapan webcam...');
        await dio.post(
          'gate/upload-capture-response',
          data: formData,
        );
        debugPrint('[AutoCapture] Unggah selesai untuk RFID $rfidUid');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil memotret & mengirim data untuk RFID $rfidUid!'),
              backgroundColor: AppTheme.emerald,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('[AutoCapture] Gagal memotret/mengunggah secara otomatis: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-Capture Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

Widget _buildSectionTitle(IconData icon, String title) {
return Row(
children: [
Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: AppTheme.maroon.withOpacity(0.1),
borderRadius: BorderRadius.circular(8)),
child: Icon(icon, size: 16, color: AppTheme.maroon),
),
const SizedBox(width: 10),
Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w800,
fontSize: 15,
color: AppTheme.slate900),
),
],
);
}

Widget _buildEmergencySectionCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.orange.withOpacity(0.3)),
      boxShadow: AppTheme.subtleShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(IconlyLight.danger, color: Colors.orange, size: 18),
            SizedBox(width: 8),
            Text(
              'Emergency Override',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Aksi di bawah ini akan membuka gerbang secara paksa dan dicatat sebagai aksi darurat.',
          style: TextStyle(fontSize: 12, color: AppTheme.slate500),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleEmergencyOpen('masuk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(IconlyLight.login, size: 16),
                label: const Text('Gate Masuk',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleEmergencyOpen('keluar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(IconlyLight.logout, size: 16),
                label: const Text('Gate Keluar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _buildActiveEmergencyGuestsList(),
      ],
    ),
  );
}

Widget _buildActiveEmergencyGuestsList() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Tamu Darurat Aktif di Kampus',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.slate800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      FutureBuilder<Response>(
        future: ref.read(dioProvider).get('gate/emergency-guests'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                ),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Text(
              'Gagal memuat daftar tamu',
              style: TextStyle(fontSize: 11, color: Colors.red),
            );
          }
          final list = snapshot.data!.data as List<dynamic>;
          if (list.isEmpty) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada tamu darurat aktif',
                  style: TextStyle(fontSize: 11, color: AppTheme.slate400, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final nama = item['nama'] ?? '';
              final plat = item['plat_nomor'] ?? '';
              final alasan = item['alasan'] ?? '';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Alasan: $alasan',
                            style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Text(
                        plat,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

Widget _buildCameraSection({required bool isDesktop}) {
return Container(
decoration: BoxDecoration(
color: const Color(0xFF0F172A),
borderRadius: BorderRadius.circular(20),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.1),
blurRadius: 10,
offset: const Offset(0, 4),
),
],
),
child: Column(
children: [
Container(
padding: const EdgeInsets.symmetric(
horizontal: 16, vertical: 10),
decoration: const BoxDecoration(
color: Color(0xFF1E293B),
borderRadius: BorderRadius.only(
topLeft: Radius.circular(20),
topRight: Radius.circular(20)),
),
child: Row(
children: [
Container(
width: 8,
height: 8,
decoration: BoxDecoration(
color: _showCamera && _cameraUrl != null
? Colors.greenAccent
: const Color(0xFFEF4444),
shape: BoxShape.circle,
boxShadow: [],
),
),
const SizedBox(width: 10),
Expanded(
child: Text(
_showCamera && _cameraUrl != null
? 'LIVE — Gate Camera'
: 'OFFLINE',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: _showCamera && _cameraUrl != null
? Colors.greenAccent
: const Color(0xFF94A3B8),
fontSize: 12,
fontWeight: FontWeight.w700,
letterSpacing: 0.5),
),
),
const SizedBox(width: 8),
if (_showCamera && _cameraType == 'device_camera') ...[
GestureDetector(
onTap: _captureAndScanDeviceCamera,
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 12, vertical: 5),
decoration: BoxDecoration(
color: AppTheme.emerald.withOpacity(0.9),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: AppTheme.emerald.withOpacity(0.3)),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: const [
Icon(IconlyLight.scan,
color: Colors.white,
size: 14),
SizedBox(width: 5),
Text('Scan Plat',
style: TextStyle(
color: Colors.white,
fontSize: 11,
fontWeight: FontWeight.w600)),
],
),
),
),
const SizedBox(width: 8),
],
GestureDetector(
onTap: _showCameraDialog,
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 12, vertical: 5),
decoration: BoxDecoration(
color: Colors.white.withOpacity(0.08),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: Colors.white.withOpacity(0.1)),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
_showCamera && _cameraUrl != null
? IconlyLight.setting
: IconlyLight.camera,
color: const Color(0xFF94A3B8),
size: 14),
const SizedBox(width: 5),
Text(_showCamera && _cameraUrl != null ? 'Setting' : 'Connect',
style: const TextStyle(
color: Color(0xFF94A3B8),
fontSize: 11,
fontWeight: FontWeight.w600)),
],
),
),
),
],
),
),
ClipRRect(
borderRadius: const BorderRadius.only(
bottomLeft: Radius.circular(20),
bottomRight: Radius.circular(20)),
child: AspectRatio(
aspectRatio: 16 / 9,
child: _showCamera && _cameraUrl != null
? Stack(
children: [
Positioned.fill(
child: _cameraType == 'device_camera'
? WebCameraViewer(controller: _cameraController)
: WebMjpegViewer(streamUrl: _cameraUrl!),
),
// HUD Gradient Overlay
Positioned.fill(
child: Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.black.withOpacity(0.4),
Colors.transparent,
Colors.transparent,
Colors.black.withOpacity(0.5),
],
stops: const [0.0, 0.2, 0.8, 1.0],
),
),
),
),
// Blinking REC Indicator
Positioned(
top: 12,
left: 12,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.5),
borderRadius: BorderRadius.circular(6),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 8,
height: 8,
decoration: const BoxDecoration(
color: Colors.red,
shape: BoxShape.circle,
),
).animate(onPlay: (controller) => controller.repeat(reverse: true))
.fadeOut(duration: 500.ms),
const SizedBox(width: 6),
const Text(
'REC',
style: TextStyle(
color: Colors.white,
fontSize: 9,
fontWeight: FontWeight.bold,
letterSpacing: 1,
),
),
],
),
),
),
// Live Clock
Positioned(
top: 12,
right: 12,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.5),
borderRadius: BorderRadius.circular(6),
),
child: StreamBuilder<DateTime>(
stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
builder: (context, snapshot) {
final now = snapshot.data ?? DateTime.now();
final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
return Text(
timeStr,
style: const TextStyle(
color: Colors.white,
fontFamily: 'Courier',
fontSize: 10,
fontWeight: FontWeight.bold,
),
);
},
),
),
),
// Bottom HUD Labels
Positioned(
bottom: 12,
left: 12,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Colors.black.withOpacity(0.5),
borderRadius: BorderRadius.circular(6),
),
child: Text(
_cameraType == 'device_camera' ? 'CAM_GATE_ENTRY_WEBCAM' : 'CAM_GATE_ENTRY_IP',
style: const TextStyle(
color: Colors.white70,
fontFamily: 'Courier',
fontSize: 9,
fontWeight: FontWeight.bold,
),
),
),
),
Positioned(
bottom: 12,
right: 12,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: AppTheme.emerald.withOpacity(0.2),
borderRadius: BorderRadius.circular(6),
border: Border.all(color: AppTheme.emerald.withOpacity(0.5)),
),
child: const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(Icons.shield, color: AppTheme.emerald, size: 10),
SizedBox(width: 4),
Text(
'SECURE FEED',
style: TextStyle(
color: AppTheme.emerald,
fontSize: 9,
fontWeight: FontWeight.bold,
),
),
],
),
),
),
],
)
: Stack(
children: [
Positioned.fill(
child: Container(
color: const Color(0xFF0F172A),
child: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(IconlyLight.camera,
color: const Color(0xFFEF4444).withOpacity(0.6), size: 48)
.animate(onPlay: (controller) => controller.repeat(reverse: true))
.fadeOut(duration: 800.ms),
const SizedBox(height: 12),
const Text(
'NO SIGNAL',
style: TextStyle(
color: Color(0xFFEF4444),
fontSize: 13,
fontWeight: FontWeight.bold,
letterSpacing: 1,
),
),
const SizedBox(height: 4),
const Text(
'Tap "Connect" to configure gate camera',
style: TextStyle(
color: Color(0xFF475569),
fontSize: 11,
),
),
],
),
),
),
),
const Positioned(
top: 12,
left: 12,
child: Text(
'LIVE GATE FEED — OFFLINE',
style: TextStyle(
color: Colors.white24,
fontFamily: 'Courier',
fontSize: 9,
fontWeight: FontWeight.bold,
),
),
),
],
),
),
),
],
),
);
}

Widget _buildChartSection(AsyncValue<List<dynamic>> chartAsync) {
return chartAsync.when(
data: (chartData) => Container(
padding: const EdgeInsets.fromLTRB(16, 20, 20, 12),
decoration: AppTheme.modernCard,
child: Column(
children: [
Row(
children: [
Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: AppTheme.tealLight,
borderRadius: BorderRadius.circular(8)),
child: const Icon(IconlyLight.chart,
size: 16, color: AppTheme.teal),
),
const SizedBox(width: 10),
const Text('Tren Parkir (7 Hari)',
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 15,
color: AppTheme.slate900)),
],
),
const SizedBox(height: 16),
ParkingChart(chartData: chartData),
],
),
),
loading: () => const Center(
child: Padding(
padding: EdgeInsets.all(20),
child: CircularProgressIndicator())),
error: (e, _) => const SizedBox.shrink(),
);
}

Widget _buildAlprSectionHeader() {
return Row(
children: [
Container(
padding: const EdgeInsets.all(6),
decoration: BoxDecoration(
color: AppTheme.emerald.withOpacity(0.1),
borderRadius: BorderRadius.circular(8)),
child: const Icon(IconlyLight.scan,
size: 16, color: AppTheme.emerald),
),
const SizedBox(width: 10),
const Text('ALPR Output',
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 15,
color: AppTheme.slate900)),
const Spacer(),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 8, vertical: 3),
decoration: BoxDecoration(
color: AppTheme.emerald.withOpacity(0.1),
borderRadius: BorderRadius.circular(6)),
child: Text('${logs.length} scan',
style: const TextStyle(
fontSize: 10,
color: AppTheme.emerald,
fontWeight: FontWeight.w700)),
),
],
);
}

Widget _buildAlprSectionContent() {
if (logs.isEmpty) {
return Container(
height: 120,
decoration: BoxDecoration(
color: const Color(0xFF0F172A),
borderRadius: BorderRadius.circular(16),
),
child: const Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(IconlyLight.scan,
size: 32, color: Color(0xFF334155)),
SizedBox(height: 8),
Text('Menunggu scan kendaraan...',
style: TextStyle(
color: Color(0xFF475569), fontSize: 12)),
]),
),
);
}

return Column(
children: logs.map((log) {
final isSuccess = log['type'] == 'success';
final imagePath = log['image_path'];

return Container(
margin: const EdgeInsets.only(bottom: 10),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: const Color(0xFF1E293B).withOpacity(0.6),
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: isSuccess
? AppTheme.emerald.withOpacity(0.3)
: const Color(0xFFEF4444).withOpacity(0.3),
width: 1.5,
),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.2),
blurRadius: 8,
offset: const Offset(0, 4),
),
],
),
child: Row(
children: [
Container(
width: 38,
height: 38,
decoration: BoxDecoration(
color: (isSuccess
? AppTheme.emerald
: const Color(0xFFEF4444))
.withOpacity(0.15),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
isSuccess
? Icons.check_circle_rounded
: Icons.cancel_rounded,
color: isSuccess
? AppTheme.emerald
: const Color(0xFFEF4444),
size: 22),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Wrap(
crossAxisAlignment: WrapCrossAlignment.center,
spacing: 8,
runSpacing: 4,
children: [
Text(
log['plate'] ?? 'UNKNOWN',
style: const TextStyle(
fontFamily: 'Courier',
fontWeight: FontWeight.w900,
fontSize: 18,
color: Colors.white,
letterSpacing: 2),
),
if (log['gate'] != null)
Container(
padding: const EdgeInsets.symmetric(
horizontal: 6, vertical: 2),
decoration: BoxDecoration(
color: Colors.white10,
borderRadius: BorderRadius.circular(4),
),
child: Text(
log['gate'].toString().toUpperCase(),
style: const TextStyle(
fontSize: 9,
color: Colors.white60,
fontWeight: FontWeight.bold),
),
),
],
),
const SizedBox(height: 4),
Text(
'${log['message'] ?? '-'} • ${log['user'] ?? '-'}',
style: const TextStyle(
fontSize: 12, color: Color(0xFF94A3B8)),
),
],
),
),
if (imagePath != null && imagePath.toString().isNotEmpty) ...[
const SizedBox(width: 12),
GestureDetector(
onTap: () {
showDialog(
context: context,
builder: (context) => Dialog(
backgroundColor: Colors.transparent,
insetPadding: const EdgeInsets.all(20),
child: ClipRRect(
borderRadius: BorderRadius.circular(20),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
InteractiveViewer(
child: Image.network(
"${AppConstants.uploadBaseUrl}$imagePath",
fit: BoxFit.contain,
errorBuilder: (context, error, stackTrace) => Container(
height: 200,
color: const Color(0xFF0F172A),
child: const Center(
child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
),
),
),
),
Container(
width: double.infinity,
color: const Color(0xFF0F172A),
padding: const EdgeInsets.all(16),
child: Column(
children: [
Text(
log['plate'] ?? 'UNKNOWN',
style: const TextStyle(
fontFamily: 'Courier',
color: Colors.white,
fontSize: 20,
fontWeight: FontWeight.bold,
letterSpacing: 2,
),
),
const SizedBox(height: 4),
Text(
log['user'] ?? '',
style: const TextStyle(color: Colors.white70, fontSize: 14),
),
],
),
),
],
),
),
),
);
},
child: Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(10),
border: Border.all(color: Colors.white24),
),
child: ClipRRect(
borderRadius: BorderRadius.circular(9),
child: Image.network(
"${AppConstants.uploadBaseUrl}$imagePath",
width: 70,
height: 46,
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) => Container(
width: 70,
height: 46,
color: Colors.white.withOpacity(0.05),
child: const Icon(Icons.image_not_supported, size: 16, color: Colors.white24),
),
),
),
),
),
],
],
),
);
}).toList(),
);
}

@override
Widget build(BuildContext context) {
ref.watch(refreshTriggerProvider); // Auto rebuild on WS / global trigger
final chartAsync = ref.watch(activityChartProvider);
final size = MediaQuery.of(context).size;
final isDesktop = size.width >= 900;

if (isDesktop) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
flex: 3,
child: ListView(
padding: const EdgeInsets.all(24),
children: [
_buildCameraSection(isDesktop: true),
const SizedBox(height: 24),
_buildAlprSectionHeader(),
const SizedBox(height: 12),
_buildAlprSectionContent(),
],
),
),
const VerticalDivider(width: 1, thickness: 1),
Expanded(
flex: 2,
child: ListView(
padding: const EdgeInsets.all(24),
children: [
_buildSectionTitle(Icons.dashboard_rounded, 'Overview & Statistik'),
const SizedBox(height: 12),
const SessionStatsSummary(),
const SizedBox(height: 24),
_buildEmergencySectionCard(),
const SizedBox(height: 24),
_buildChartSection(chartAsync),
],
),
),
],
);
}

return Column(
children: [
Expanded(
child: ListView(
padding: const EdgeInsets.only(top: 16),
children: [
const SessionStatsSummary(),
const SizedBox(height: 8),
_buildCameraSection(isDesktop: false),
const SizedBox(height: 16),
_buildAlprSectionHeader(),
const SizedBox(height: 8),
_buildAlprSectionContent(),
const SizedBox(height: 16),
_buildChartSection(chartAsync),
const SizedBox(height: 20),
],
),
),
_buildEmergencyPanel(),
],
);
}

Widget _buildEmergencyPanel() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey[200]!)),
      boxShadow: [],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isEmergencyExpanded = !_isEmergencyExpanded;
            });
          },
          child: Row(
            children: [
              const Icon(IconlyLight.danger, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text('Emergency Override',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.orange)),
              const Spacer(),
              Icon(
                _isEmergencyExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                color: Colors.orange,
              ),
            ],
          ),
        ),
        if (_isEmergencyExpanded) ...[
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleEmergencyOpen('masuk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(IconlyLight.login, size: 18),
                label: const Text('Buka Gate Masuk',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _handleEmergencyOpen('keluar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(IconlyLight.logout, size: 18),
                label: const Text('Buka Gate Keluar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildActiveEmergencyGuestsList(),
            ],
          ),
        ]
      ],
    ),
  );
}

Future<void> _handleEmergencyOpen(String gate) async {
List<dynamic> guests = [];
if (gate == 'keluar') {
try {
final response = await ref.read(dioProvider).get('gate/emergency-guests');
guests = response.data;
} catch (e) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil daftar tamu: $e')));
}
return;
}
}

final reasonController = TextEditingController();
final nameController = TextEditingController();
final vehicleController = TextEditingController();
int? selectedGuestId;
bool hasScanned = false;
bool isScanning = false;
String scanStatus = "";

Future<void> lookupGuestName(String plate, StateSetter setStateDialog, BuildContext dialogCtx) async {
if (plate.trim().isEmpty) return;
try {
final response = await ref.read(dioProvider).get(
'gate/emergency-guest-lookup',
queryParameters: {'plate': plate.trim()},
);
final data = response.data;
if (!dialogCtx.mounted) return;
if (data['status'] == 'success') {
final previousName = data['previous_name'] as String? ?? '';
if (previousName.isNotEmpty) {
setStateDialog(() {
nameController.text = previousName;
});
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Nama tamu otomatis diisi dari riwayat kunjungan sebelumnya'),
duration: Duration(seconds: 2),
),
);
}
} else {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Tidak ada riwayat nama untuk plat ini'),
duration: Duration(seconds: 2),
),
);
}
}
}
} catch (e) {
if (mounted && dialogCtx.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('Gagal mencari riwayat: $e')),
);
}
}
}
Future<void> doScan(StateSetter setStateDialog, BuildContext dialogCtx) async {
if (!dialogCtx.mounted) return;
setStateDialog(() {
isScanning = true;
scanStatus = "Memindai plat nomor...";
});
try {
Response response;
if (_cameraType == 'device_camera') {
// Capture image bytes from the browser webcam (regular scan device camera)
final bytes = await _cameraController.capture();
if (bytes == null) {
setStateDialog(() {
isScanning = false;
scanStatus = "Gagal mengambil gambar dari webcam. Pastikan kamera aktif.";
});
return;
}

final formData = FormData.fromMap({
'gate_type': gate,
'file': MultipartFile.fromBytes(
bytes,
filename: 'emergency_capture.jpg',
contentType: MediaType('image', 'jpeg'),
),
});

response = await ref.read(dioProvider).post(
'gate/scan-emergency-plate',
data: formData,
);
} else {
// Trigger scan using backend camera stream
final formData = FormData.fromMap({
'gate_type': gate,
if (_cameraUrl != null && _cameraUrl!.isNotEmpty)
'camera_url': _cameraUrl!,
});

response = await ref.read(dioProvider).post(
'gate/scan-emergency-plate',
data: formData,
);
}

final data = response.data;
if (!dialogCtx.mounted) return;
if (data['status'] == 'success') {
final detectedPlate = data['detected_plate'] as String? ?? '';
final previousName = data['previous_name'] as String? ?? '';
setStateDialog(() {
isScanning = false;
if (detectedPlate.isNotEmpty) {
vehicleController.text = detectedPlate;
scanStatus = "Pemindaian berhasil!";
} else {
scanStatus = "Kamera tidak mendeteksi plat nomor.";
}
if (previousName.isNotEmpty) {
nameController.text = previousName;
}
});
} else {
setStateDialog(() {
isScanning = false;
scanStatus = "Gagal memindai plat.";
});
}
} catch (e) {
if (!dialogCtx.mounted) return;
setStateDialog(() {
isScanning = false;
scanStatus = "Error pemindaian: $e";
});
}
}

bool confirmed = await showDialog(
context: context,
builder: (ctx) => StatefulBuilder(
builder: (contextDialog, setStateDialog) {
if (!hasScanned) {
hasScanned = true;
WidgetsBinding.instance.addPostFrameCallback((_) {
doScan(setStateDialog, contextDialog);
});
}

return AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: Row(
children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.orange.withOpacity(0.1),
borderRadius: BorderRadius.circular(10),
),
child: const Icon(IconlyLight.danger, color: Colors.orange, size: 24),
),
const SizedBox(width: 12),
Expanded(
child: Text(
'Peringatan: Emergency $gate',
style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
),
),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Text(
'Aksi ini akan membuka gerbang secara paksa dan dicatat oleh sistem.',
style: TextStyle(color: AppTheme.slate500, fontSize: 13),
),
const SizedBox(height: 12),
if (scanStatus.isNotEmpty) ...[
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: isScanning
? Colors.orange.withOpacity(0.1)
: (scanStatus.contains('berhasil') ? Colors.green.withOpacity(0.1) : AppTheme.slate100),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: isScanning
? Colors.orange.withOpacity(0.3)
: (scanStatus.contains('berhasil') ? Colors.green.withOpacity(0.3) : AppTheme.slate200),
),
),
child: Row(
children: [
if (isScanning)
const SizedBox(
width: 14,
height: 14,
child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
)
else
Icon(
scanStatus.contains('berhasil') ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
color: scanStatus.contains('berhasil') ? Colors.green : AppTheme.slate500,
size: 16,
),
const SizedBox(width: 8),
Expanded(
child: Text(
scanStatus,
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
color: isScanning
? Colors.orange[800]
: (scanStatus.contains('berhasil') ? Colors.green[800] : AppTheme.slate600),
),
),
),
],
),
),
const SizedBox(height: 12),
],
if (gate == 'keluar' && guests.isNotEmpty) ...[
DropdownButtonFormField<int>(
isExpanded: true,
decoration: InputDecoration(
hintText: 'Pilih Tamu Darurat (Opsional)',
prefixIcon: const Icon(IconlyLight.user_1, size: 20),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
value: selectedGuestId,
items: guests.map((g) {
return DropdownMenuItem<int>(
value: g['id'] as int,
child: Text(
'${g['nama']} (${g['plat_nomor']})',
overflow: TextOverflow.ellipsis,
),
);
}).toList(),
onChanged: (val) {
setStateDialog(() {
selectedGuestId = val;
});
},
),
const SizedBox(height: 12),
const Text(
'ATAU isi manual jika tamu tidak ada di daftar:',
style: TextStyle(fontSize: 12, color: AppTheme.slate400, fontWeight: FontWeight.w600),
),
const SizedBox(height: 12),
],
if (gate == 'masuk' || (gate == 'keluar' && selectedGuestId == null)) ...[
TextField(
controller: nameController,
decoration: InputDecoration(
hintText: 'Nama Tamu',
prefixIcon: const Icon(IconlyLight.profile, size: 20),
suffixIcon: IconButton(
icon: const Icon(Icons.search_rounded, color: AppTheme.slate400, size: 20),
tooltip: 'Cari nama dari riwayat plat',
onPressed: () => lookupGuestName(vehicleController.text, setStateDialog, contextDialog),
),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
const SizedBox(height: 12),
TextField(
controller: vehicleController,
decoration: InputDecoration(
hintText: 'Plat Kendaraan',
prefixIcon: const Icon(IconlyLight.document, size: 20),
suffixIcon: isScanning
? const Padding(
padding: EdgeInsets.all(12.0),
child: SizedBox(
width: 16,
height: 16,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.orange,
),
),
)
: IconButton(
icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.orange, size: 20),
tooltip: 'Pindai Ulang',
onPressed: () => doScan(setStateDialog, contextDialog),
),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
),
),
const SizedBox(height: 12),
],

TextField(
controller: reasonController,
maxLines: 2,
decoration: InputDecoration(
hintText: 'Alasan darurat (opsional)...',
prefixIcon: const Padding(
padding: EdgeInsets.only(bottom: 24),
child: Icon(IconlyLight.chat, size: 20),
),
filled: true,
fillColor: AppTheme.slate50,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppTheme.slate200),
),
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
),
),
],
),
),
actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
style: TextButton.styleFrom(foregroundColor: AppTheme.slate500),
child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
),
ElevatedButton(
onPressed: () {
if (gate == 'masuk' && (nameController.text.isEmpty || vehicleController.text.isEmpty)) {
ScaffoldMessenger.of(ctx).showSnackBar(
const SnackBar(content: Text('Nama dan Kendaraan wajib diisi', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
);
return;
}
if (gate == 'keluar' && selectedGuestId == null && (nameController.text.isEmpty || vehicleController.text.isEmpty)) {
ScaffoldMessenger.of(ctx).showSnackBar(
const SnackBar(content: Text('Pilih tamu atau isi manual', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
);
return;
}
Navigator.pop(ctx, true);
},
style: ElevatedButton.styleFrom(
backgroundColor: Colors.orange,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
),
child: const Text('Konfirmasi Buka', style: TextStyle(fontWeight: FontWeight.bold)),
),
],
);
},
),
) ??
false;

if (confirmed && mounted) {
try {
final queryParams = {
'gate': gate,
'reason': reasonController.text,
};
if (selectedGuestId != null) {
queryParams['guest_id'] = selectedGuestId.toString();
} else {
queryParams['nama'] = nameController.text;
queryParams['kendaraan'] = vehicleController.text;
}

final response = await ref.read(dioProvider).post('gate/emergency-action', queryParameters: queryParams);
if (mounted) {
final msg = response.data['message'] ?? 'Berhasil';
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
} catch (e) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
}
}
}
}
}

// ── PERMINTAAN TAB WITH FILTER ─────────────────────────────
class PermintaanTabWithFilter extends ConsumerStatefulWidget {
final VoidCallback? onCountChanged;
const PermintaanTabWithFilter({super.key, this.onCountChanged});

@override
ConsumerState<PermintaanTabWithFilter> createState() =>
_PermintaanTabWithFilterState();
}

class _PermintaanTabWithFilterState
extends ConsumerState<PermintaanTabWithFilter> {
String _selectedFilter = 'gerbang'; // 'gerbang' or 'stnk'

@override
Widget build(BuildContext context) {
return Column(
children: [
// Filter Toggle
Padding(
padding: const EdgeInsets.all(16),
child: FilterToggle(
options: const [
FilterOption(
value: 'gerbang',
label: 'Permintaan Gerbang',
icon: Icons.pending_actions_rounded,
),
FilterOption(
value: 'stnk',
label: 'Verifikasi STNK',
icon: Icons.verified_rounded,
),
],
selectedValue: _selectedFilter,
onChanged: (value) => setState(() => _selectedFilter = value),
),
),

// Content based on filter
Expanded(
child: _selectedFilter == 'gerbang'
? AccessRequestQueueTab(onCountChanged: widget.onCountChanged)
: const VerifikasiTab(),
),
],
);
}
}

// ── ACCESS REQUEST QUEUE TAB ───────────────────────────────
class AccessRequestQueueTab extends ConsumerStatefulWidget {
final VoidCallback? onCountChanged;
const AccessRequestQueueTab({super.key, this.onCountChanged});

@override
ConsumerState<AccessRequestQueueTab> createState() =>
_AccessRequestQueueTabState();
}

class _AccessRequestQueueTabState extends ConsumerState<AccessRequestQueueTab> {
Future<List<dynamic>> fetchPendingRequests() async {
final response =
await ref.read(dioProvider).get('petugas/access-requests/pending');
return response.data;
}

Future<void> _respond(int requestId, String action,
{String catatan = ''}) async {
try {
await ref.read(dioProvider).put(
'petugas/access-requests/$requestId/respond',
queryParameters: {'action': action, 'catatan': catatan},
);
if (mounted) {
final msg = action == 'disetujui'
? '✓ Disetujui, gate dibuka'
: '✗ Permintaan ditolak';
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(msg),
backgroundColor:
action == 'disetujui' ? Colors.green : AppTheme.maroon,
behavior: SnackBarBehavior.floating,
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
),
);
widget.onCountChanged?.call();
setState(() {});
}
} catch (e) {
if (mounted) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text('Error: $e')));
}
}
}

final List<String> _quickReasons = [
"STNK Kadaluarsa",
"Foto STNK Buram",
"Plat Nomor Tidak Sesuai",
"Bukan Mahasiswa Aktif",
"Pajak Kendaraan Mati"
];

void _showRejectDialog(int requestId) {
final catatanController = TextEditingController();
showDialog(
context: context,
builder: (ctx) => StatefulBuilder(
builder: (context, setStateDialog) => AlertDialog(
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: Row(
children: const [
Icon(Icons.close_rounded, color: AppTheme.maroon),
SizedBox(width: 8),
Expanded(
child: Text('Tolak Permintaan'),
),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('Alasan Cepat:',
style:
TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
const SizedBox(height: 8),
Wrap(
spacing: 6,
runSpacing: 6,
children: _quickReasons
.map((reason) => GestureDetector(
onTap: () {
catatanController.text = reason;
setStateDialog(() {});
},
child: Chip(
label: Text(reason,
style: const TextStyle(fontSize: 10)),
backgroundColor: catatanController.text == reason
? AppTheme.maroon.withOpacity(0.1)
: Colors.grey.withOpacity(0.1),
padding: EdgeInsets.zero,
materialTapTargetSize:
MaterialTapTargetSize.shrinkWrap,
),
))
.toList(),
),
const SizedBox(height: 16),
const Text('Alasan penolakan (opsional):'),
const SizedBox(height: 4),
TextField(
controller: catatanController,
maxLines: 3,
decoration: const InputDecoration(
hintText: 'Tulis alasan di sini...'),
),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Batal')),
ElevatedButton.icon(
style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon),
onPressed: () {
Navigator.pop(ctx);
_respond(requestId, 'ditolak', catatan: catatanController.text);
},
icon: const Icon(Icons.close_rounded, size: 16),
label: const Text('Tolak'),
),
],
),
),
);
}

@override
Widget build(BuildContext context) {
ref.watch(refreshTriggerProvider); // Auto-refresh when WS event occurs

return RefreshIndicator(
color: AppTheme.maroon,
onRefresh: () async {
ref.read(refreshTriggerProvider.notifier).state++;
widget.onCountChanged?.call();
},
child: FutureBuilder<List<dynamic>>(
future: fetchPendingRequests(),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(color: AppTheme.maroon));
}
if (!snapshot.hasData || snapshot.data!.isEmpty) {
return _buildEmptyState(Icons.check_rounded,
'Tidak ada permintaan\nyang menunggu');
}

return ListView.builder(
itemCount: snapshot.data!.length,
padding: const EdgeInsets.all(16),
itemBuilder: (context, index) {
final r = snapshot.data![index];
final isMasuk = r['jenis_aktivitas'] == 'masuk';
return Card(
margin: const EdgeInsets.only(bottom: 12),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(
color: isMasuk
? Colors.green.withOpacity(0.1)
: AppTheme.maroonSurface,
borderRadius: BorderRadius.circular(12),
),
child: Icon(
isMasuk
? IconlyLight.login
: IconlyLight.logout,
color: isMasuk ? Colors.green : AppTheme.maroon,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(r['user_nama'],
style: const TextStyle(
fontWeight: FontWeight.w700,
fontSize: 16)),
Text('NIM: ${r['user_nim']}',
style: const TextStyle(
fontSize: 12, color: Colors.grey)),
],
),
),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10, vertical: 5),
decoration: BoxDecoration(
color: isMasuk ? Colors.green : AppTheme.maroon,
borderRadius: BorderRadius.circular(8),
),
child: Text(
isMasuk ? 'MASUK' : 'KELUAR',
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w700,
fontSize: 12),
),
),
],
),
if (r['is_flagged'] == true)
Container(
margin: const EdgeInsets.only(top: 8),
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Colors.orange.withOpacity(0.1),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: Colors.orange.withOpacity(0.3))),
child: Row(
children: [
const Icon(IconlyLight.danger,
color: Colors.orange, size: 20),
const SizedBox(width: 8),
Expanded(
child: Text(
'PERINGATAN: ${r['flag_reason'] ?? "User ini ditandai oleh petugas."}',
style: const TextStyle(
color: Colors.orange,
fontSize: 12,
fontWeight: FontWeight.bold),
),
),
],
),
),
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: const Color(0xFFF8F4F4),
borderRadius: BorderRadius.circular(8),
),
child: Row(
children: [
Expanded(
child: _InfoChip(
icon: Icons.directions_car,
label:
'${r['vehicle_jenis']} • ${r['vehicle_plat']}')),
const SizedBox(width: 8),
Expanded(
child: _InfoChip(
icon: Icons.nfc,
label: r['rfid_uid'] ?? 'No RFID')),
],
),
),
Padding(
padding: const EdgeInsets.only(top: 6),
child: Text(
'🕐 ${r['waktu_request'] ?? '-'}',
style:
const TextStyle(fontSize: 11, color: Colors.grey),
),
),
const Divider(height: 20),
Row(
children: [
Expanded(
child: OutlinedButton.icon(
style: OutlinedButton.styleFrom(
foregroundColor: AppTheme.maroon,
side: const BorderSide(color: AppTheme.maroon),
padding:
const EdgeInsets.symmetric(vertical: 10),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8)),
),
onPressed: () => _showRejectDialog(r['id']),
icon: const Icon(Icons.close_rounded, size: 16),
label: const Text('Tolak'),
),
),
const SizedBox(width: 12),
Expanded(
flex: 2,
child: ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.green,
foregroundColor: Colors.white,
padding:
const EdgeInsets.symmetric(vertical: 10),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8)),
),
onPressed: () => _respond(r['id'], 'disetujui'),
icon: const Icon(Icons.check_rounded, size: 16),
label: const Text('Setujui & Buka Gate'),
),
),
],
),
],
),
),
);
},
);
},
),
);
}
}

// ── VERIFIKASI STNK TAB ────────────────────────────────────
class VerifikasiTab extends ConsumerStatefulWidget {
const VerifikasiTab({super.key});

@override
ConsumerState<VerifikasiTab> createState() => _VerifikasiTabState();
}

class _VerifikasiTabState extends ConsumerState<VerifikasiTab> {
Future<List<dynamic>> fetchPending() async {
final response =
await ref.read(dioProvider).get('petugas/vehicles/pending');
return response.data;
}

Future<void> _updateStatus(int id, String status) async {
try {
await ref
.read(dioProvider)
.put('petugas/vehicles/$id/verify?status=$status');
setState(() {});
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
content: Text(status == 'disetujui'
? '✓ Kendaraan disetujui'
: '✗ Kendaraan ditolak'),
backgroundColor: status == 'disetujui' ? Colors.green : AppTheme.maroon,
behavior: SnackBarBehavior.floating,
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
));
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text('Error: $e')));
}
}

@override
Widget build(BuildContext context) {
return RefreshIndicator(
color: AppTheme.maroon,
onRefresh: () async => setState(() {}),
child: FutureBuilder<List<dynamic>>(
future: fetchPending(),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(color: AppTheme.maroon));
}
if (!snapshot.hasData || snapshot.data!.isEmpty) {
return _buildEmptyState(Icons.fact_check_outlined,
'Tidak ada kendaraan\nyang menunggu verifikasi');
}

return ListView.builder(
itemCount: snapshot.data!.length,
padding: const EdgeInsets.all(16),
itemBuilder: (context, index) {
final v = snapshot.data![index];
final isMotor = v['jenis_kendaraan'] == 'Motor';
final hasStnk = v['foto_stnk'] != null &&
v['foto_stnk'].toString().isNotEmpty;
return Card(
margin: const EdgeInsets.only(bottom: 12),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Container(
width: 48,
height: 48,
decoration: BoxDecoration(
color: AppTheme.maroonSurface,
borderRadius: BorderRadius.circular(12),
),
child: Icon(
isMotor
? Icons.motorcycle_rounded
: Icons.shield_rounded,
color: AppTheme.maroon,
size: 26,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(v['plat_nomor'],
style: const TextStyle(
fontWeight: FontWeight.w800,
fontSize: 20)),
Text(
'${v['jenis_kendaraan']} | User ID: ${v['user_id']}',
style: const TextStyle(
fontSize: 13, color: Colors.grey)),
],
),
),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10, vertical: 5),
decoration: BoxDecoration(
color: const Color(0xFFFFF3CC),
borderRadius: BorderRadius.circular(8),
border:
Border.all(color: const Color(0xFFD4A843)),
),
child: const Text('PENDING',
style: TextStyle(
color: Color(0xFF8B6914),
fontWeight: FontWeight.w700,
fontSize: 11)),
),
],
),
const SizedBox(height: 12),
// STNK photo indicator
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: hasStnk ? Colors.green[50] : Colors.orange[50],
borderRadius: BorderRadius.circular(8),
),
child: Row(
children: [
Icon(
hasStnk
? Icons.image_rounded
: Icons.image_not_supported_outlined,
size: 16,
color: hasStnk ? Colors.green : Colors.orange,
),
const SizedBox(width: 6),
Expanded(
child: Text(
hasStnk
? 'Foto STNK tersedia'
: 'Foto STNK belum diupload',
style: TextStyle(
color:
hasStnk ? Colors.green : Colors.orange,
fontSize: 12),
),
),
if (hasStnk)
TextButton(
onPressed: () => showStnkPhotoDialog(
context, v['foto_stnk']),
child: const Text('Lihat',
style: TextStyle(fontSize: 12)),
),
],
),
),
const Divider(height: 20),
Row(
children: [
Expanded(
child: OutlinedButton.icon(
style: OutlinedButton.styleFrom(
foregroundColor: AppTheme.maroon,
side: const BorderSide(color: AppTheme.maroon),
padding:
const EdgeInsets.symmetric(vertical: 10),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8)),
),
onPressed: () =>
_updateStatus(v['id'], 'ditolak'),
icon: const Icon(Icons.close_rounded, size: 16),
label: const Text('Tolak'),
),
),
const SizedBox(width: 12),
Expanded(
flex: 2,
child: ElevatedButton.icon(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.green,
foregroundColor: Colors.white,
padding:
const EdgeInsets.symmetric(vertical: 10),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8)),
),
onPressed: () =>
_updateStatus(v['id'], 'disetujui'),
icon: const Icon(Icons.check_rounded, size: 16),
label: const Text('Setujui STNK'),
),
),
],
),
],
),
),
);
},
);
},
),
);
}
}

// ── SEARCH MEMBER TAB ──────────────────────────────────────
class SearchMemberTab extends ConsumerStatefulWidget {
const SearchMemberTab({super.key});

@override
ConsumerState<SearchMemberTab> createState() => _SearchMemberTabState();
}

class _SearchMemberTabState extends ConsumerState<SearchMemberTab> {
final _searchController = TextEditingController();
List<dynamic> _results = [];
bool _loading = false;

void _search() async {
if (_searchController.text.isEmpty) return;
setState(() => _loading = true);
try {
final res = await ref.read(dioProvider).get('petugas/search',
queryParameters: {'query': _searchController.text});
setState(() => _results = res.data);
} catch (e) {
if (mounted)
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text('Error: $e')));
} finally {
setState(() => _loading = false);
}
}

void _toggleFlag(int userId, bool currentStatus) async {
final reasonController = TextEditingController();
bool? confirmed = await showDialog(
context: context,
builder: (ctx) => AlertDialog(
title: Text(currentStatus ? 'Hapus Peringatan?' : 'Tambah Peringatan?'),
content: currentStatus
? const Text(
'Yakin ingin menghapus status peringatan pada user ini?')
: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Text(
'User ini akan ditandai pada setiap request akses masa depan.'),
const SizedBox(height: 12),
TextField(
controller: reasonController,
decoration: const InputDecoration(
hintText:
'Alasan peringatan (misal: Sering parkir sembarang)')),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
child: const Text('Batal')),
TextButton(
onPressed: () => Navigator.pop(ctx, true),
style: TextButton.styleFrom(
foregroundColor: currentStatus ? Colors.green : Colors.orange),
child: Text(currentStatus ? 'HAPUS' : 'SET FLAG'),
),
],
),
);

if (confirmed == true && mounted) {
try {
await ref.read(dioProvider).put('petugas/flag-user/$userId',
queryParameters: {
'is_flagged': !currentStatus,
'reason': reasonController.text
});
_search(); // Refresh
} catch (e) {
if (mounted)
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text('Gagal: $e')));
}
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF8F4F4),
body: Column(
children: [
Padding(
padding: const EdgeInsets.all(16),
child: TextField(
controller: _searchController,
decoration: InputDecoration(
hintText: 'Cari NIM, Nama, atau Plat Nomor...',
prefixIcon: const Icon(IconlyLight.search),
suffixIcon: IconButton(
icon: const Icon(Icons.close_rounded),
onPressed: () => _searchController.clear()),
filled: true,
fillColor: Colors.white,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(16),
borderSide: BorderSide.none,
),
contentPadding: const EdgeInsets.symmetric(vertical: 16),
),
onSubmitted: (_) => _search(),
),
),
if (_loading) const LinearProgressIndicator(color: AppTheme.maroon),
Expanded(
child: _results.isEmpty
? ModernEmptyState(
icon: Icons.person_search_rounded,
title: 'Cari Pengguna',
subtitle:
'Ketikkan NIM, Nama, atau Plat Nomor\nuntuk melihat detail member.',
)
: ListView.builder(
itemCount: _results.length,
padding:
const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
itemBuilder: (context, index) {
final u = _results[index];
final isFlagged = u['is_flagged'] == true;
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
border: isFlagged
? Border.all(
color: Colors.orange.withOpacity(0.5))
: null,
boxShadow: [],
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
CircleAvatar(
radius: 24,
backgroundColor: isFlagged
? Colors.orange[100]
: AppTheme.maroonSurface,
child: Icon(
isFlagged
? IconlyLight.danger
: IconlyLight.profile,
color: isFlagged
? Colors.orange
: AppTheme.maroon),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Expanded(
child: Text(u['nama'],
style: const TextStyle(
fontWeight: FontWeight.w800,
fontSize: 16))),
IconButton(
icon: Icon(
isFlagged
? Icons.flag
: Icons.flag_outlined,
color: isFlagged
? Colors.orange
: Colors.grey,
size: 20),
onPressed: () =>
_toggleFlag(u['id'], isFlagged),
padding: EdgeInsets.zero,
constraints: const BoxConstraints(),
),
],
),
const SizedBox(height: 4),
Text('NIM: ${u['nim']}',
style: TextStyle(
color: Colors.grey[600],
fontSize: 13)),
const SizedBox(height: 12),
if ((u['vehicles'] as List).isNotEmpty) ...[
Wrap(
spacing: 8,
runSpacing: 8,
children: (u['vehicles'] as List)
.map((v) => Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 4),
decoration: BoxDecoration(
color: AppTheme.maroon
.withOpacity(0.05),
borderRadius:
BorderRadius.circular(8),
),
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
v['jenis'] == 'Motor'
? Icons
.motorcycle_rounded
: Icons
.directions_car_rounded,
size: 14,
color: AppTheme.maroon),
const SizedBox(width: 4),
Text(v['plat'],
style: const TextStyle(
fontSize: 12,
fontWeight:
FontWeight.w700,
color: AppTheme
.maroon)),
],
),
))
.toList(),
),
] else ...[
Text('Belum ada kendaraan',
style: TextStyle(
color: Colors.grey[400],
fontSize: 12,
fontStyle: FontStyle.italic)),
],
if (isFlagged) ...[
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10, vertical: 6),
decoration: BoxDecoration(
color: Colors.orange.withOpacity(0.1),
borderRadius:
BorderRadius.circular(8)),
child: Row(
children: [
const Icon(Icons.info_outline,
size: 14, color: Colors.orange),
const SizedBox(width: 8),
Expanded(
child: Text(
'Ket: ${u['flag_reason']}',
style: const TextStyle(
color: Colors.orange,
fontSize: 11,
fontWeight:
FontWeight.w600))),
],
),
),
],
],
),
),
],
),
);
},
),
),
],
),
);
}
}

// ── Shared Helpers ─────────────────────────────────────────
Widget _buildEmptyState(IconData icon, String message) {
final parts = message.split('\n');
return ListView(
children: [
const SizedBox(height: 80),
ModernEmptyState(
icon: icon,
title: parts.isNotEmpty ? parts[0] : '',
subtitle: parts.length > 1 ? parts.sublist(1).join('\n') : '',
),
],
);
}

class _InfoChip extends StatelessWidget {
final IconData icon;
final String label;
const _InfoChip({required this.icon, required this.label});

@override
Widget build(BuildContext context) {
return Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, size: 14, color: Colors.grey),
const SizedBox(width: 4),
Flexible(
child: Text(label,
style: const TextStyle(fontSize: 12, color: Colors.grey),
overflow: TextOverflow.ellipsis)),
],
);
}
}
