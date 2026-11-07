import 'package:flutter_test/flutter_test.dart';
import 'package:it7_lab_act/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Uses MyApp as defined in lib/main.dart
    await tester.pumpWidget(const MyApp());
  });
}
