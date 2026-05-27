import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_campus_parking/main.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartParkingApp()));

    expect(find.text('Masuk'), findsWidgets);
    expect(find.text('NIM / NPP'), findsOneWidget);
  });
}
