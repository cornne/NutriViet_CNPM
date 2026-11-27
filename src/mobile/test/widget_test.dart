import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutriviet_mobile/l10n/app_locale.dart';
import 'package:nutriviet_mobile/main.dart';
import 'package:nutriviet_mobile/screens/allergy_profile_screen.dart';
import 'package:nutriviet_mobile/screens/community_feed_screen.dart';
import 'package:nutriviet_mobile/screens/home_screen.dart';
import 'package:nutriviet_mobile/screens/login_screen.dart';
import 'package:nutriviet_mobile/screens/register_screen.dart';
import 'package:nutriviet_mobile/screens/settings_screen.dart';
import 'package:nutriviet_mobile/services/auth_service.dart';
import 'package:nutriviet_mobile/services/local_guest_store.dart';
import 'package:nutriviet_mobile/services/perf_monitor.dart';
import 'package:nutriviet_mobile/services/profile_service.dart';
import 'package:nutriviet_mobile/theme/nutriviet_glass.dart';
import 'package:nutriviet_mobile/theme/nutriviet_route.dart';
import 'package:nutriviet_mobile/widgets/nutriviet_glass_modal.dart';
import 'package:nutriviet_mobile/widgets/nutriviet_notice.dart';
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
    expect(find.text('Ghi nhớ đăng nhập'), findsNothing);
    expect(find.text('Welcome back'), findsNothing);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Remember me'), findsNothing);
    expect(find.text('Chào mừng trở lại'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AllergyProfileScreen focuses on allergies and health without body metrics clutter', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    await tester.pumpWidget(
      const MaterialApp(
        home: AllergyProfileScreen(
          userId: 0,
          userName: 'Khách',
          isGuest: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hồ Sơ Dị Ứng & Sức Khỏe'), findsOneWidget);
    expect(find.text('Nhóm dị ứng thực phẩm'), findsOneWidget);
    expect(find.text('Đậu phộng'), findsOneWidget);
    expect(find.text('Sữa & Chế phẩm'), findsOneWidget);

    // Tapping an allergen card activates it and shows severity pill
    await tester.tap(find.text('Đậu phộng'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Sốc phản vệ'), findsOneWidget);

    // Lazy Sliver CustomScrollView builds lower sections smoothly as user scrolls
    await tester.scrollUntilVisible(
      find.text('Tình trạng sức khỏe'),
      250.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tình trạng sức khỏe'), findsOneWidget);

    // Must NOT contain gender, height, weight, age, or BMI form clutter
    expect(find.text('Giới tính'), findsNothing);
    expect(find.text('Chiều cao'), findsNothing);
    expect(find.text('Cân nặng'), findsNothing);
    expect(find.text('Tuổi'), findsNothing);
    expect(find.textContaining('BMI'), findsNothing);
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
    expect(find.text('Dị ứng & sức khỏe'), findsOneWidget);
    expect(find.text('Hồ sơ gia đình'), findsOneWidget);
    expect(find.text('Tình trạng của tôi'), findsNothing);
    expect(find.text('Quản lý hồ sơ'), findsNothing);
    expect(find.text('Quản lý dị ứng'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Ngôn ngữ'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chúc mừng huy hiệu'), findsNothing);
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
    expect(find.text('Allergies & health'), findsOneWidget);
    expect(find.text('Family profiles'), findsOneWidget);
    expect(find.text('My conditions'), findsNothing);
    expect(find.text('Manage profiles'), findsNothing);
    expect(find.text('Manage allergies'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Language'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsScreen summarizes health profile and manages family members in Guest mode', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    await LocalGuestStore.saveAllergens([
      {'code': 'peanuts', 'name': 'Đậu phộng', 'severity': 'high'},
    ]);
    await LocalGuestStore.saveChronics([
      {'code': 'diabetes', 'name': 'Tiểu đường'},
    ]);

    var callbackCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            userId: 0,
            userName: 'Khách',
            userEmail: '',
            isGuest: true,
            onProfileUpdated: () => callbackCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 dị ứng · 1 bệnh nền'), findsOneWidget);
    expect(find.text('Hồ sơ gia đình'), findsOneWidget);

    await tester.tap(find.text('Hồ sơ gia đình'));
    await tester.pumpAndSettle();

    expect(find.text('Thành viên (1)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Bé An');
    await tester.tap(find.text('Con cái'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm thành viên'));
    await tester.pumpAndSettle();

    expect(find.text('Thành viên (2)'), findsOneWidget);
    expect(find.text('Bé An'), findsOneWidget);
    expect(callbackCount, greaterThanOrEqualTo(1));

    await tester.tap(find.byTooltip('Xóa thành viên'));
    await tester.pumpAndSettle();

    expect(find.text('Thành viên (1)'), findsOneWidget);
    expect(find.text('Bé An'), findsNothing);
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

  test('ProfileService targets Cloudflare Workers HTTPS exclusively without localhost probes', () {
    final releaseRoots = ProfileService.buildApiRoots(
      isReleaseMode: true,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    expect(releaseRoots, [ProfileService.cloudApiRoot]);
    expect(releaseRoots, isNot(contains('http://127.0.0.1:8050/api/v1')));
    expect(releaseRoots, isNot(contains('http://192.168.1.15:8050/api/v1')));
    expect(releaseRoots, isNot(contains('http://10.0.2.2:8050/api/v1')));

    final debugRoots = ProfileService.buildApiRoots(
      isReleaseMode: false,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    expect(debugRoots, [ProfileService.cloudApiRoot]);
  });

  test('LocalGuestStore persists locally and survives AuthService.logout until cleared', () async {
    expect(await LocalGuestStore.hasLocalData(), isFalse);

    final guest = await AuthService.enterGuestMode();
    expect(AuthService.isGuest(guest), isTrue);
    expect(AuthService.isAdmin(guest), isFalse);

    final session = await AuthService.getSession();
    expect(AuthService.isGuest(session), isTrue);

    await LocalGuestStore.saveAllergens([
      {'code': 'milk', 'name': 'Milk', 'severity': 'high'},
    ]);
    await LocalGuestStore.saveChronics([
      {'code': 'diabetes', 'name': 'Diabetes'},
    ]);
    await LocalGuestStore.addFamilyMember(
      memberName: 'Bé An',
      relationship: 'Con',
    );
    final defaultSettings = await LocalGuestStore.getSettings();
    expect((defaultSettings['settings'] as Map)['scan_derivatives'], isTrue);
    expect((defaultSettings['settings'] as Map)['warn_traces'], isTrue);

    await LocalGuestStore.saveSettings({
      'language': 'vi',
      'notify_badges': true,
      'notify_reminders': false,
      'scan_derivatives': false,
      'warn_traces': false,
    });

    expect(await LocalGuestStore.hasLocalData(), isTrue);
    final alRes = await LocalGuestStore.getAllergens();
    expect((alRes['allergens'] as List).length, 1);
    final famRes = await LocalGuestStore.getFamilyMembers();
    expect((famRes['members'] as List).length, 2);
    final savedSettings = await LocalGuestStore.getSettings();
    expect((savedSettings['settings'] as Map)['scan_derivatives'], isFalse);
    expect((savedSettings['settings'] as Map)['warn_traces'], isFalse);

    // Guest has no Bearer token
    expect(await AuthService.getToken(), isEmpty);

    // Logout removes only auth session keys so Guest local data can be synced on login
    await AuthService.logout();
    expect(await AuthService.getSession(), isNull);
    expect(await LocalGuestStore.hasLocalData(), isTrue);

    await LocalGuestStore.clearAll();
    expect(await LocalGuestStore.hasLocalData(), isFalse);
  });

  test('AuthService.getToken returns Bearer token for signed-in accounts and empty for guests', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'nv_live_session_token_abc',
      'is_guest': false,
    });
    expect(await AuthService.getToken(), 'nv_live_session_token_abc');

    await AuthService.enterGuestMode();
    expect(await AuthService.getToken(), isEmpty);
  });

  test('LocalGuestStore deleteScan and clearScans update local scan history accurately', () async {
    final nowIso = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'nv_guest_scans':
          '[{"id":101,"label_title":"Sữa tươi","raw_text":"milk","risk_level":"safe","warning_count":0,"additive_count":1,"created_at":"$nowIso"},'
          '{"id":102,"label_title":"Bánh quy","raw_text":"peanut, E102","risk_level":"high","warning_count":2,"additive_count":2,"created_at":"$nowIso"}]',
    });

    final before = await LocalGuestStore.getScans();
    expect(before['total_scans'], 2);
    expect(before['warning_scans'], 1);
    expect(before['monthly_warnings'], 2);

    final afterDelete = await LocalGuestStore.deleteScan(102);
    expect(afterDelete['success'], isTrue);
    expect(afterDelete['total_scans'], 1);
    expect(afterDelete['warning_scans'], 0);
    expect(afterDelete['monthly_warnings'], 0);
    expect(((afterDelete['scans'] as List).first as Map)['id'], 101);

    final afterClear = await LocalGuestStore.clearScans();
    expect(afterClear['success'], isTrue);
    expect(afterClear['deleted_count'], 1);
    expect(afterClear['total_scans'], 0);
    expect(afterClear['scans'], isEmpty);
  });

  test('AuthService role helpers distinguish guest, user, and admin strictly', () {
    expect(AuthService.isAdmin({'id': 1, 'role': 'admin', 'token': 'tok', 'is_guest': false}), isTrue);
    expect(AuthService.isAdmin({'id': 2, 'role': 'user', 'token': 'tok', 'is_guest': false}), isFalse);
    expect(AuthService.isAdmin({'id': 0, 'role': 'admin', 'token': '', 'is_guest': true}), isFalse);
    expect(AuthService.isGuest({'id': 0, 'role': 'guest', 'token': '', 'is_guest': true}), isTrue);
    expect(AuthService.isGuest({'id': 2, 'role': 'user', 'token': 'tok', 'is_guest': false}), isFalse);
  });

  testWidgets('CommunityFeedScreen blocks Guests with Sign-In gate and hides Admin UI', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityFeedScreen(
            embedded: true,
            user: {
              'id': 0,
              'full_name': 'Khách',
              'role': 'guest',
              'token': '',
              'is_guest': true,
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Mạng xã hội Cộng đồng'), findsOneWidget);
    expect(find.text('Đăng nhập để mở khóa'), findsOneWidget);
    expect(find.text('+ Đăng bài'), findsNothing);
    expect(find.byIcon(PhosphorIconsFill.shieldCheck), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CommunityFeedScreen shows Admin Shield ONLY for admin role', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityFeedScreen(
            key: ValueKey('community_user'),
            embedded: true,
            user: {
              'id': 10,
              'full_name': 'Normal User',
              'role': 'user',
              'token': 'fake-user-token',
              'is_guest': false,
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Cộng đồng'), findsOneWidget);
    expect(find.text('+ Đăng bài'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.shieldCheck), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityFeedScreen(
            key: ValueKey('community_admin'),
            embedded: true,
            user: {
              'id': 1,
              'full_name': 'Admin',
              'role': 'admin',
              'token': 'fake-admin-token',
              'is_guest': false,
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(PhosphorIconsFill.shieldCheck), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsScreen exposes hidden Admin row only to admin and Cloud Sync to Guest', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    // Standard user must NOT see Admin Moderation
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(
          key: ValueKey('settings_user_rbac'),
          userId: 10,
          userName: 'Alice',
          userEmail: 'alice@example.com',
          userRole: 'user',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Tài khoản'),
      250.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Quản trị Cộng đồng'), findsNothing);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Admin user MUST see hidden Admin Moderation row
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(
          key: ValueKey('settings_admin_rbac'),
          userId: 1,
          userName: 'Admin',
          userEmail: 'admin@nutriviet.vn',
          userRole: 'admin',
          authToken: 'admin-token',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Quản trị Cộng đồng'),
      250.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Quản trị Cộng đồng'), findsOneWidget);

    // Guest user MUST see Sign In & Cloud Sync, never Admin Moderation
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(
          key: ValueKey('settings_guest_rbac'),
          userId: 0,
          userName: 'Khách',
          userEmail: '',
          isGuest: true,
          userRole: 'guest',
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Đăng nhập & Đồng bộ Cloud'),
      250.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Đăng nhập & Đồng bộ Cloud'), findsOneWidget);
    expect(find.text('Quản trị Cộng đồng'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen replaces Additives tab with Community tab on bottom navigation', (
    WidgetTester tester,
  ) async {
    await AppLocale.setLanguage('vi');
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(
          user: {
            'id': 0,
            'full_name': 'Khách',
            'email': '',
            'role': 'guest',
            'token': '',
            'is_guest': true,
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Cộng đồng'), findsWidgets);
    expect(find.text('Phụ gia'), findsNothing);
    expect(find.text('Huy hiệu'), findsNothing);
    expect(find.text('Badges'), findsNothing);
    expect(find.textContaining('miễn phí'), findsNothing);
    expect(find.textContaining('free scan'), findsNothing);
    expect(find.byIcon(PhosphorIconsDuotone.chatsCircle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showNutriVietNotice renders floating frosted pill toast cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showNutriVietNotice(
                ctx,
                'Đã lưu hồ sơ sức khỏe thành công.',
                tone: NutriVietNoticeTone.success,
              ),
              child: const Text('Trigger'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Đã lưu hồ sơ sức khỏe thành công.'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsFill.checkCircle), findsOneWidget);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.backgroundColor, Colors.transparent);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'NutriVietFloatingBottomBar aligns tab bar and scan orb on Android 16 edge-to-edge inset',
    (WidgetTester tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(434, 964),
              padding: EdgeInsets.only(top: 41, bottom: 24),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  const SizedBox.expand(),
                  NutriVietFloatingBottomBar(
                    selectedIndex: selected,
                    onChanged: (i) => selected = i,
                    onScanTap: () {},
                    items: const [
                      NutriVietBottomTabItem(
                        icon: PhosphorIconsRegular.house,
                        selectedIcon: PhosphorIconsFill.house,
                        label: 'Trang chủ',
                      ),
                      NutriVietBottomTabItem(
                        icon: PhosphorIconsRegular.usersThree,
                        selectedIcon: PhosphorIconsFill.usersThree,
                        label: 'Cộng đồng',
                      ),
                      NutriVietBottomTabItem(
                        icon: PhosphorIconsRegular.clockCounterClockwise,
                        selectedIcon: PhosphorIconsFill.clockCounterClockwise,
                        label: 'Lịch sử',
                      ),
                      NutriVietBottomTabItem(
                        icon: PhosphorIconsRegular.slidersHorizontal,
                        selectedIcon: PhosphorIconsFill.slidersHorizontal,
                        label: 'Cài đặt',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabBarRect = tester.getRect(find.byType(AnimatedAlign));
      final scanOrbRect = tester.getRect(find.byIcon(PhosphorIconsBold.scan));
      // Vertical centers of the tab bar and scan orb must match within 2dp (no double bottomInset!)
      expect((tabBarRect.center.dy - scanOrbRect.center.dy).abs(), lessThanOrEqualTo(2.0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SettingsScreen bounces cleanly past overscroll limits instead of sticking flat',
    (WidgetTester tester) async {
      await AppLocale.setLanguage('vi');
      await tester.pumpWidget(
        const MaterialApp(
          scrollBehavior: NutriVietScrollBehavior(),
          home: Scaffold(
            body: SettingsScreen(
              userId: 0,
              userName: 'Khách',
              userEmail: '',
              isGuest: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listFinder);
      expect(listView.physics, isA<BouncingScrollPhysics>());

      final scrollableState = tester.state<ScrollableState>(find.byType(Scrollable).first);
      // Drag downward past the top limit — must overscroll smoothly (< 0) then spring back to 0.
      final gesture = await tester.startGesture(tester.getCenter(listFinder));
      await gesture.moveBy(const Offset(0, 180));
      await tester.pump();
      expect(scrollableState.position.pixels, lessThan(0.0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, closeTo(0.0, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'NutriVietTabView lazily mounts tabs on first visit and preserves state across switches',
    (WidgetTester tester) async {
      int activeTab = 0;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              outerSetState = setState;
              return NutriVietTabView(
                index: activeTab,
                children: const [
                  Center(child: Text('TabZeroBody')),
                  Center(child: Text('TabOneLazyBody')),
                  Center(child: Text('TabTwoLazyBody')),
                ],
              );
            },
          ),
        ),
      );

      // Only Tab 0 is mounted initially; Tabs 1 & 2 are not built yet
      expect(find.text('TabZeroBody'), findsOneWidget);
      expect(find.text('TabOneLazyBody', skipOffstage: false), findsNothing);
      expect(find.text('TabTwoLazyBody', skipOffstage: false), findsNothing);

      // Switch to Tab 1 -> lazily mounts Tab 1 while keeping Tab 0 alive offstage
      outerSetState(() => activeTab = 1);
      await tester.pumpAndSettle();
      expect(find.text('TabOneLazyBody'), findsOneWidget);
      expect(find.text('TabZeroBody', skipOffstage: false), findsOneWidget);
      expect(find.text('TabTwoLazyBody', skipOffstage: false), findsNothing);

      // Switch back to Tab 0 -> Tab 1 stays alive offstage
      outerSetState(() => activeTab = 0);
      await tester.pumpAndSettle();
      expect(find.text('TabZeroBody'), findsOneWidget);
      expect(find.text('TabOneLazyBody', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'NutriVietPageRoute transitions cleanly without M3 saveLayer zoom route',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NutriVietPageTransitionsBuilder(),
                TargetPlatform.iOS: NutriVietPageTransitionsBuilder(),
                TargetPlatform.windows: NutriVietPageTransitionsBuilder(),
                TargetPlatform.linux: NutriVietPageTransitionsBuilder(),
                TargetPlatform.macOS: NutriVietPageTransitionsBuilder(),
                TargetPlatform.fuchsia: NutriVietPageTransitionsBuilder(),
              },
            ),
          ),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    NutriVietPageRoute(
                      builder: (_) => Scaffold(
                        body: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('SecondRoute'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('OpenRoute'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenRoute'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      // Both incoming and outgoing routes must use zero-saveLayer GPU
      // SlideTransition rather than full-screen FadeTransition / M3 zoom.
      expect(
        find.ancestor(
          of: find.text('SecondRoute'),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
      expect(find.byType(FadeTransition), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('SecondRoute'), findsOneWidget);

      await tester.tap(find.text('SecondRoute'));
      await tester.pumpAndSettle();
      expect(find.text('OpenRoute'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'NutriVietShimmerGroup uses a single shared RepaintBoundary across all bones',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NutriVietShimmerGroup(
              child: Column(
                children: [
                  NutriVietShimmerBox(width: 100, height: 14),
                  NutriVietShimmerBox(width: 140, height: 14),
                  NutriVietShimmerBox(width: 80, height: 14),
                  NutriVietShimmerBox.circle(size: 32),
                ],
              ),
            ),
          ),
        ),
      );

      final groupFinder = find.byType(NutriVietShimmerGroup);
      final boundariesInsideGroup = find.descendant(
        of: groupFinder,
        matching: find.byType(RepaintBoundary),
      );
      expect(find.byType(NutriVietShimmerBox), findsNWidgets(4));
      // Exactly 1 shared RepaintBoundary on the group, never 1 per bone.
      expect(boundariesInsideGroup, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HomeScreen hydrates Stale-While-Revalidate snapshot immediately without waiting for network',
    (WidgetTester tester) async {
      await AppLocale.setLanguage('vi');
      SharedPreferences.setMockInitialValues({
        'nv_home_snapshot_v1_u_42': jsonEncode({
          'allergens': [],
          'family_members': [
            {'id': 1, 'member_name': 'Me', 'is_primary': 1},
            {'id': 2, 'member_name': 'Bé An', 'is_primary': 0},
          ],
          'scans': [],
          'monthly_scans': 7,
          'monthly_warnings': 2,
          'selected_member': 'Bé An',
          'category': 'salt',
          'category_items': [
            {
              'id': 'salt_1',
              'code': 'FOODON:00001111',
              'title_en': 'Refined Table Salt',
              'description_en': 'High sodium food seasoning.',
              'risk_level': 'high',
            },
          ],
        }),
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(
            user: {
              'id': 42,
              'full_name': 'Minh Anh',
              'email': 'minh@example.com',
              'role': 'user',
              'token': 'test-token',
              'is_guest': false,
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Bé An'), findsOneWidget);
      expect(find.text('Refined Table Salt'), findsOneWidget);
      expect(find.textContaining('Đã đọc 7 nhãn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('NutriVietPerfMonitor tracks frame build/raster stats and 120Hz budget misses', () {
    NutriVietPerfMonitor.reset();
    NutriVietPerfMonitor.recordSample(buildUs: 1200, rasterUs: 2400); // 3.6ms OK
    NutriVietPerfMonitor.recordSample(buildUs: 2500, rasterUs: 3000); // 5.5ms OK
    NutriVietPerfMonitor.recordSample(buildUs: 4500, rasterUs: 5500); // 10.0ms >8.33ms
    NutriVietPerfMonitor.recordSample(buildUs: 8000, rasterUs: 11000); // 19.0ms >16.67ms

    final snap = NutriVietPerfMonitor.snapshot();
    expect(snap['frames'], 4);
    expect(snap['over_120hz'], 2);
    expect(snap['over_60hz'], 1);
    expect(snap['build_avg_ms'], closeTo(4.05, 0.01));
    expect(snap['raster_avg_ms'], closeTo(5.475, 0.01));
  });

  testWidgets(
    'Design system uses zero-violet clinical teal palette and vector allergen icons',
    (WidgetTester tester) async {
      await tester.pumpWidget(const NutriVietApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.colorScheme.secondary, NutriVietGlass.brandTeal);
      expect(app.theme?.colorScheme.secondary, isNot(const Color(0xFF4F37C8)));

      await tester.pumpWidget(
        const MaterialApp(
          home: AllergyProfileScreen(
            userId: 0,
            userName: 'Khách',
            isGuest: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Primary 8 allergen cards must render cohesive Phosphor vector icons,
      // never raw OS cartoon emoji text.
      expect(find.byIcon(PhosphorIconsDuotone.acorn), findsOneWidget);
      expect(find.byIcon(PhosphorIconsDuotone.shrimp), findsOneWidget);
      expect(find.text('🥜'), findsNothing);
      expect(find.text('🦐'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RegisterScreen isolates live password requirements and allows tapping full Terms row',
    (WidgetTester tester) async {
      await AppLocale.setLanguage('vi');
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Password requirements appear reactively when typing without form errors.
      final passwordField = find.widgetWithText(TextFormField, 'Tối thiểu 8 ký tự');
      await tester.enterText(passwordField, 'Abc12345');
      await tester.pump();
      expect(find.text('8+ ký tự'), findsOneWidget);
      expect(find.text('Chữ hoa'), findsOneWidget);
      expect(find.text('Số'), findsOneWidget);
      expect(find.text('Rất mạnh'), findsOneWidget);

      // Tapping the Terms label text toggles the checkbox cleanly.
      final termsText = find.text('Tôi đồng ý với Điều khoản & Cam kết bảo mật y tế');
      await tester.ensureVisible(termsText);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(termsText);
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

void _noop() {}
