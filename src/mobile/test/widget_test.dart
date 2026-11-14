import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriviet_mobile/l10n/app_locale.dart';
import 'package:nutriviet_mobile/main.dart';
import 'package:nutriviet_mobile/screens/login_screen.dart';
import 'package:nutriviet_mobile/screens/settings_screen.dart';
import 'package:nutriviet_mobile/services/profile_service.dart';
import 'package:nutriviet_mobile/theme/nutriviet_glass.dart';
import 'package:nutriviet_mobile/widgets/nutriviet_glass_modal.dart';
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

  testWidgets('NutriVietHorizontalFadeScroll fades only overflowing edges', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: NutriVietHorizontalFadeScroll(
              child: Row(
                children: [
                  SizedBox(width: 80, height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: NutriVietHorizontalFadeScroll(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  SizedBox(width: 120, height: 40, child: Text('Đường')),
                  SizedBox(width: 10),
                  SizedBox(width: 120, height: 40, child: Text('Muối')),
                  SizedBox(width: 10),
                  SizedBox(width: 120, height: 40, child: Text('Chất béo')),
                  SizedBox(width: 10),
                  SizedBox(width: 120, height: 40, child: Text('Dị ứng')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showNutriVietGlassSheet toggles check rows and dismisses cleanly', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<Set<String>> selected = ValueNotifier<Set<String>>({});
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showNutriVietGlassSheet<void>(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Tình trạng của tôi'),
                        ValueListenableBuilder<Set<String>>(
                          valueListenable: selected,
                          builder: (_, items, __) => NutriVietGlassCheckRow(
                            title: 'Tiểu đường',
                            subtitle: 'Cảnh báo đường tinh luyện',
                            checked: items.contains('diabetes'),
                            onTap: () {
                              final next = Set<String>.from(items);
                              if (!next.add('diabetes')) {
                                next.remove('diabetes');
                              }
                              selected.value = next;
                            },
                          ),
                        ),
                        const NutriVietGlassOptionRow(
                          title: 'Tiếng Việt',
                          subtitle: 'Giao diện tiếng Việt',
                          selected: true,
                          onTap: _noop,
                        ),
                        NutriVietGlassPillButton(
                          label: 'Xong',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Mở sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Tình trạng của tôi'), findsOneWidget);
    expect(selected.value, isEmpty);

    await tester.tap(find.text('Tiểu đường'));
    await tester.pumpAndSettle();
    expect(selected.value, contains('diabetes'));

    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('Tình trạng của tôi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showNutriVietGlassDialog renders and dismisses cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showNutriVietGlassDialog<void>(
                    context: context,
                    builder: (ctx) => NutriVietGlassDialog(
                      title: const Text('Đổi mật khẩu tài khoản'),
                      content: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu hiện tại',
                        ),
                      ),
                      actions: [
                        NutriVietGlassPillButton(
                          label: 'Hủy',
                          variant: NutriVietGlassButtonVariant.neutral,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        const NutriVietGlassPillButton(
                          label: 'Lưu mật khẩu',
                          onPressed: _noop,
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Mở dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Đổi mật khẩu tài khoản'), findsOneWidget);
    expect(find.text('Lưu mật khẩu'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Đổi mật khẩu tài khoản'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('ProfileService prioritizes PythonAnywhere HTTPS in release mode without LAN probes', () {
    final releaseRoots = ProfileService.buildApiRoots(
      isReleaseMode: true,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    expect(releaseRoots.first, ProfileService.cloudApiRoot);
    expect(releaseRoots, isNot(contains('http://192.168.1.15:8050/api/v1')));
    expect(releaseRoots, isNot(contains('http://10.0.2.2:8050/api/v1')));

    final debugRoots = ProfileService.buildApiRoots(
      isReleaseMode: false,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    expect(debugRoots.first, 'http://127.0.0.1:8050/api/v1');
    expect(debugRoots[1], ProfileService.cloudApiRoot);
  });
}

void _noop() {}
