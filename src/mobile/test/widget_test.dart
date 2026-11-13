import 'package:flutter_test/flutter_test.dart';

import 'package:nutriviet_mobile/main.dart';

void main() {
  testWidgets('NutriVietApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriVietApp());
    expect(find.byType(NutriVietApp), findsOneWidget);
  });
}
