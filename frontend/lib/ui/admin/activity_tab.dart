import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logs_tab.dart';

/// Activity Tab - Shows all system activities and logs
class ActivityTab extends ConsumerWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse LogsTab for activity monitoring
    return const LogsTab();
  }
}
