import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kukupaja_app/main.dart';

void main() {
  testWidgets('KukuPaja splash loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KukuPajaApp());
    expect(find.text('KukuPaja'), findsOneWidget);
    expect(find.text('Soko la kuku, moja kwa moja.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
