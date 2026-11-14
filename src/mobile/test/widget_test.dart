import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriviet_mobile/l10n/app_locale.dart';
import 'package:nutriviet_mobile/main.dart';
import 'package:nutriviet_mobile/screens/login_screen.dart';
import 'package:nutriviet_mobile/screens/settings_screen.dart';
import 'package:nutriviet_mobile/theme/nutriviet_glass.dart';
import 'package:nutriviet_mobile/widgets/nutriviet_shimmer.dart';
import 'package:nutriviet_mobile/widgets/nutriviet_ui.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocale.setLanguage('vi');
  });

  testWidgets('NutriVietApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriVietApp());
    expect(find.byType(NutriVietApp), findsOneWidget);
  });

  testWidgets('NutriVietShimmer skeletons render and animate cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                NutriVietHomeStatsSkeleton(),
                SizedBox(height: 12),
                NutriVietConceptListSkeleton(itemCount: 2),
                SizedBox(height: 12),
                NutriVietHistoryListSkeleton(itemCount: 2),
                SizedBox(height: 12),
                NutriVietFoodSearchSkeleton(itemCount: 2),
                SizedBox(height: 12),
                NutriVietAllergyProfileSkeleton(),
                SizedBox(height: 12),
                NutriVietShimmerGroup(
                  child: NutriVietSettingsRowSkeleton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(NutriVietShimmerGroup), findsWidgets);
    expect(find.byType(NutriVietShimmerBox), findsWidgets);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('NutriVietGlassCard and NutriVietGlassActionButton states work', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NutriVietGlassBackdrop(
            child: NutriVietGlassScrollArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const NutriVietGlassCard(
                    child: Text('Frosted Card Content'),
                  ),
                  const SizedBox(height: 12),
                  NutriVietGlassActionButton(
                    label: 'Primary Action',
                    icon: Icons.check,
                    onPressed: () => tapped = true,
                  ),
                  const SizedBox(height: 12),
                  const NutriVietGlassActionButton(
                    label: 'Loading Action',
                    isLoading: true,
                    onPressed: null,
                  ),
                  const SizedBox(height: 12),
                  NutriVietGlassActionButton(
                    label: 'Secondary Action',
                    isPrimary: false,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 12),
                  NutriVietGlassActionButton(
                    label: 'Danger Action',
                    isDanger: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Frosted Card Content'), findsOneWidget);
    expect(find.text('Primary Action'), findsOneWidget);
    expect(find.byType(NutriVietShimmerBox), findsWidgets);

    await tester.tap(find.text('Primary Action'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoginScreen renders in VI and toggles strictly to EN', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Chào mừng trở lại'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsScreen renders in VI and EN with shimmer loading', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(
          key: ValueKey('settings_vi'),
          userId: 1,
          userName: 'An Nguyễn',
          userEmail: 'an@example.com',
        ),
      ),
    );

    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.byType(NutriVietSettingsRowSkeleton), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Ngôn ngữ'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await AppLocale.setLanguage('en');
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(
          key: ValueKey('settings_en'),
          userId: 1,
          userName: 'An Nguyễn',
          userEmail: 'an@example.com',
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Language'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
