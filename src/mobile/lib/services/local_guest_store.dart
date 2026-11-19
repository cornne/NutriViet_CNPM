import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_locale.dart';
import 'profile_service.dart';

/// Purely local on-device persistence for Guest mode.
/// Nothing stored here is ever pushed to cloud tables unless the user signs in
/// and explicitly chooses to sync their local Guest records to their account.
class LocalGuestStore {
  static const String _kAllergens = 'nv_guest_allergens';
  static const String _kChronics = 'nv_guest_chronics';
  static const String _kFamily = 'nv_guest_family';
  static const String _kScans = 'nv_guest_scans';
  static const String _kSettings = 'nv_guest_settings';
  static const String _kMetrics = 'nv_guest_metrics';

  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  // ---------------------------------------------------------------------------
  // Allergens
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getAllergens() async {
    final items = await _readList(_kAllergens);
    return {'success': true, 'allergens': items};
  }

  static Future<Map<String, dynamic>> saveAllergens(
    List<Map<String, dynamic>> allergens,
  ) async {
    await _writeList(_kAllergens, allergens);
    return {
      'success': true,
      'message': AppLocale.t(
        'Đã lưu hồ sơ dị ứng trên thiết bị (Chế độ Khách).',
        'Allergy profile saved locally on this device (Guest mode).',
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Chronic Conditions
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getChronics() async {
    final items = await _readList(_kChronics);
    return {'success': true, 'chronics': items};
  }

  static Future<Map<String, dynamic>> saveChronics(
    List<Map<String, dynamic>> chronics,
  ) async {
    await _writeList(_kChronics, chronics);
    return {
      'success': true,
      'message': AppLocale.t(
        'Đã lưu tình trạng sức khỏe trên thiết bị.',
        'Health conditions saved locally on this device.',
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Family Members
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getFamilyMembers() async {
    final items = await _readList(_kFamily);
    if (items.isEmpty) {
      final primary = [
        {
          'id': 1,
          'member_name': AppLocale.t('Tôi', 'Me'),
          'relationship': AppLocale.t('Bản thân', 'Self'),
          'is_primary': 1,
        }
      ];
      await _writeList(_kFamily, primary);
      return {'success': true, 'members': primary};
    }
    return {'success': true, 'members': items};
  }

  static Future<Map<String, dynamic>> addFamilyMember({
    required String memberName,
    String relationship = 'Member',
  }) async {
    final res = await getFamilyMembers();
    final items = List<Map<String, dynamic>>.from(res['members'] as List);
    final nextId = items.fold<int>(1, (acc, m) {
      final id = m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}') ?? 0;
      return id >= acc ? id + 1 : acc;
    });
    items.add({
      'id': nextId,
      'member_name': memberName.trim(),
      'relationship': relationship.trim(),
      'is_primary': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _writeList(_kFamily, items);
    return {'success': true, 'members': items};
  }

  static Future<Map<String, dynamic>> deleteFamilyMember(int memberId) async {
    final res = await getFamilyMembers();
    final items = List<Map<String, dynamic>>.from(res['members'] as List)
      ..removeWhere((m) => m['id'] == memberId && m['is_primary'] != 1);
    await _writeList(_kFamily, items);
    return {'success': true, 'members': items};
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettings);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw);
        if (map is Map) {
          return {'success': true, 'settings': Map<String, dynamic>.from(map)};
        }
      } catch (_) {}
    }
    return {
      'success': true,
      'settings': {
        'language': AppLocale.code,
        'notify_badges': true,
        'notify_reminders': false,
        'scan_derivatives': true,
        'warn_traces': true,
      },
    };
  }

  static Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(settings));
    return {
      'success': true,
      'message': AppLocale.t('Đã lưu cài đặt trên máy.', 'Settings saved locally.'),
    };
  }

  // ---------------------------------------------------------------------------
  // Body Metrics (local only for Guest)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> getMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMetrics);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw);
        if (map is Map) {
          return {'success': true, 'metrics': Map<String, dynamic>.from(map)};
        }
      } catch (_) {}
    }
    return {
      'success': true,
      'metrics': {
        'age': 22,
        'gender': 'male',
        'height': 170.0,
        'weight': 65.0,
        'activity_level': 'moderate',
      },
    };
  }

  static Future<Map<String, dynamic>> saveMetrics({
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String activityLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kMetrics,
      jsonEncode({
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'activity_level': activityLevel,
      }),
    );
    return {'success': true};
  }

  // ---------------------------------------------------------------------------
  // Local Scan History (computed with stateless FoodOn API, stored on-device)
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> _summarizeScans(List<Map<String, dynamic>> scans) {
    final now = DateTime.now();
    final monthPrefix = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    int monthlyScans = 0;
    int monthlyWarnings = 0;
    int warningScans = 0;
    for (final s in scans) {
      final wc = (s['warning_count'] is int)
          ? s['warning_count'] as int
          : int.tryParse('${s['warning_count']}') ?? 0;
      if (wc > 0 || s['risk_level'] == 'high') warningScans++;
      final created = (s['created_at'] ?? '').toString();
      if (created.startsWith(monthPrefix)) {
        monthlyScans++;
        monthlyWarnings += wc;
      }
    }
    return {
      'success': true,
      'scans': scans,
      'total_scans': scans.length,
      'warning_scans': warningScans,
      'monthly_scans': monthlyScans,
      'monthly_warnings': monthlyWarnings,
    };
  }

  static Future<Map<String, dynamic>> getScans() async {
    final scans = await _readList(_kScans);
    return _summarizeScans(scans);
  }

  static Future<Map<String, dynamic>> createLocalScan({
    required String rawText,
    String? labelTitle,
    String memberName = '',
  }) async {
    final alRes = await getAllergens();
    final chRes = await getChronics();
    final allergens = List<Map<String, dynamic>>.from(alRes['allergens'] as List);
    final chronics = (chRes['chronics'] as List)
        .map((c) => (c is Map ? (c['code'] ?? c['chronic_code'] ?? '') : c).toString())
        .where((s) => s.isNotEmpty)
        .toList();

    final evalRes = await ProfileService.evaluateLabelStateless(
      rawText: rawText,
      allergens: allergens,
      chronics: chronics,
    );
    if (evalRes['success'] != true) {
      return evalRes;
    }

    final evaluation = Map<String, dynamic>.from(evalRes['evaluation'] as Map);
    final verdict = (evaluation['verdict'] ?? 'GREEN').toString();
    final riskLevel = (evaluation['risk_level'] ?? (verdict == 'RED' ? 'high' : (verdict == 'YELLOW' ? 'low' : 'safe'))).toString();
    final warningCount = (evaluation['warning_count'] is int)
        ? evaluation['warning_count'] as int
        : ((evaluation['red_triggers'] as List?)?.length ?? 0) +
            ((evaluation['yellow_triggers'] as List?)?.length ?? 0);
    final additiveCount = (evaluation['additive_count'] is int)
        ? evaluation['additive_count'] as int
        : ((evaluation['detected_additives'] as List?)?.length ?? 0);

    final existing = await _readList(_kScans);
    final newScan = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch,
      'member_name': memberName,
      'label_title': (labelTitle ?? '').trim().isEmpty
          ? AppLocale.t('Kết quả quét', 'Scan result')
          : labelTitle!.trim(),
      'raw_text': rawText,
      'verdict': verdict,
      'risk_level': riskLevel,
      'risk_label_vi': riskLevel == 'high'
          ? 'Nguy cơ cao'
          : (riskLevel == 'low' ? 'Nguy cơ thấp' : 'An toàn'),
      'additive_count': additiveCount,
      'warning_count': warningCount,
      'evaluation': evaluation,
      'created_at': DateTime.now().toIso8601String(),
      'is_local': true,
    };
    final updated = [newScan, ...existing].take(50).toList();
    await _writeList(_kScans, updated);
    final summary = _summarizeScans(updated);
    return {
      ...summary,
      'latest_scan': newScan,
    };
  }

  // ---------------------------------------------------------------------------
  // Sync Guest Local Data to Newly Logged-In Cloud Account
  // ---------------------------------------------------------------------------
  static Future<bool> hasLocalData() async {
    final allergens = await _readList(_kAllergens);
    final chronics = await _readList(_kChronics);
    final scans = await _readList(_kScans);
    final family = await _readList(_kFamily);
    final extraFamily = family.where((m) => m['is_primary'] != 1).toList();
    return allergens.isNotEmpty ||
        chronics.isNotEmpty ||
        scans.isNotEmpty ||
        extraFamily.isNotEmpty;
  }

  static Future<Map<String, dynamic>> syncToCloudAccount({
    required int userId,
  }) async {
    int syncedCount = 0;
    final allergens = await _readList(_kAllergens);
    final chronics = await _readList(_kChronics);
    final family = await _readList(_kFamily);
    final scans = await _readList(_kScans);

    if (allergens.isNotEmpty) {
      final existingCloud = await ProfileService.getAllergens(userId);
      final merged = <String, Map<String, dynamic>>{};
      if (existingCloud['success'] == true) {
        for (final a in (existingCloud['allergens'] as List? ?? [])) {
          if (a is Map) {
            final code = (a['code'] ?? a['allergen_code'] ?? '').toString();
            if (code.isNotEmpty) merged[code] = Map<String, dynamic>.from(a);
          }
        }
      }
      for (final a in allergens) {
        final code = (a['code'] ?? a['allergen_code'] ?? '').toString();
        if (code.isNotEmpty) merged[code] = a;
      }
      final res = await ProfileService.saveAllergens(
        userId: userId,
        allergens: merged.values.toList(),
      );
      if (res['success'] == true) syncedCount += allergens.length;
    }

    if (chronics.isNotEmpty) {
      final existingCloud = await ProfileService.getChronics(userId);
      final merged = <String, Map<String, dynamic>>{};
      if (existingCloud['success'] == true) {
        for (final c in (existingCloud['chronics'] as List? ?? [])) {
          if (c is Map) {
            final code = (c['code'] ?? c['chronic_code'] ?? '').toString();
            if (code.isNotEmpty) merged[code] = Map<String, dynamic>.from(c);
          }
        }
      }
      for (final c in chronics) {
        final code = (c['code'] ?? c['chronic_code'] ?? '').toString();
        if (code.isNotEmpty) merged[code] = c;
      }
      final res = await ProfileService.saveChronics(
        userId: userId,
        chronics: merged.values.toList(),
      );
      if (res['success'] == true) syncedCount += chronics.length;
    }

    for (final m in family.where((m) => m['is_primary'] != 1)) {
      final name = (m['member_name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final res = await ProfileService.addFamilyMember(
        userId: userId,
        memberName: name,
        relationship: (m['relationship'] ?? 'Member').toString(),
      );
      if (res['success'] == true) syncedCount++;
    }

    // Re-create scans in chronological order so newest ends up on top
    for (final s in scans.reversed) {
      final rawText = (s['raw_text'] ?? '').toString().trim();
      if (rawText.isEmpty) continue;
      final res = await ProfileService.createScan(
        userId: userId,
        rawText: rawText,
        labelTitle: (s['label_title'] ?? '').toString(),
        memberName: (s['member_name'] ?? '').toString(),
      );
      if (res['success'] == true) syncedCount++;
    }

    await clearAll();
    return {
      'success': true,
      'synced_count': syncedCount,
    };
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAllergens);
    await prefs.remove(_kChronics);
    await prefs.remove(_kFamily);
    await prefs.remove(_kScans);
    await prefs.remove(_kSettings);
    await prefs.remove(_kMetrics);
  }
}
