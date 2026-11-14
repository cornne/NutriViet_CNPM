import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global reactive UI language controller for NutriViet.
/// Strictly monolingual: 'vi' (100% Tiếng Việt) or 'en' (100% English).
/// No bilingual mixing.
class AppLocale {
  static const String _prefsKey = 'nutriviet_ui_lang';

  /// Active language code: 'vi' or 'en'
  static final ValueNotifier<String> current = ValueNotifier<String>('vi');

  static bool get isEn => current.value == 'en';
  static bool get isVi => current.value != 'en';
  static String get code => isEn ? 'en' : 'vi';

  /// Normalize any stored or backend language string ('system', 'all', etc.) to 'vi' or 'en'
  static String normalize(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'en' || v == 'english') return 'en';
    return 'vi';
  }

  /// Return the string matching the active UI language ('vi' or 'en')
  static String t(String vi, String en) => isEn ? en : vi;

  /// Load persisted language on app startup
  static Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      current.value = normalize(saved);
    } catch (_) {
      current.value = 'vi';
    }
  }

  /// Switch UI language immediately and persist to SharedPreferences
  static Future<void> setLanguage(String lang) async {
    final normalized = normalize(lang);
    if (current.value != normalized) {
      current.value = normalized;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
    } catch (_) {}
  }

  /// Translate family relationship labels dynamically
  static String translateRelationship(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty || v == 'bản thân' || v == 'self') {
      return t('Bản thân', 'Self');
    }
    if (v == 'người thân' || v == 'family' || v == 'family member') {
      return t('Người thân', 'Family');
    }
    if (v == 'con cái' || v == 'con' || v == 'child') {
      return t('Con cái', 'Child');
    }
    if (v == 'vợ/chồng' || v == 'vợ' || v == 'chồng' || v == 'spouse') {
      return t('Vợ/Chồng', 'Spouse');
    }
    if (v == 'bố/mẹ' || v == 'bố' || v == 'mẹ' || v == 'parent') {
      return t('Bố/Mẹ', 'Parent');
    }
    return raw ?? t('Người thân', 'Family');
  }

  /// Translate default member names ('Tôi' / 'Me')
  static String translateMemberName(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty || v == 'Tôi' || v == 'Me') {
      return t('Tôi', 'Me');
    }
    if (v == 'Người dùng' || v == 'User') {
      return t('Người dùng', 'User');
    }
    return v;
  }

  /// Translate allergen code to active language
  static String translateAllergenCode(String? code, {String? fallback}) {
    switch ((code ?? '').trim().toLowerCase()) {
      case 'peanuts':
        return t('Đậu phộng (Lạc)', 'Peanuts');
      case 'seafood':
        return t('Hải sản, giáp xác và cá', 'Seafood, crustaceans & fish');
      case 'milk':
        return t('Sữa bò và chế phẩm từ sữa', 'Cow\'s milk & dairy products');
      case 'gluten':
        return t('Lúa mì và đạm ngũ cốc', 'Wheat & gluten grains');
      case 'eggs':
        return t('Trứng và chế phẩm từ trứng', 'Poultry eggs & egg products');
      case 'soy':
        return t('Đậu nành (Đỗ tương)', 'Soybeans');
      case 'tree_nuts':
        return t('Các loại hạt cây (Điều, Hạnh nhân, Óc chó)', 'Tree nuts (Cashew, Almond, Walnut)');
      case 'sesame':
        return t('Hạt mè (Vừng)', 'Sesame');
      default:
        return fallback ?? (code ?? '');
    }
  }

  /// Translate chronic condition code to active language
  static String translateChronicCode(String? code, {String? fallback}) {
    switch ((code ?? '').trim().toLowerCase()) {
      case 'diabetes':
        return t('Bệnh tiểu đường', 'Type 2 Diabetes');
      case 'hypertension':
        return t('Tăng huyết áp (Giảm muối)', 'Hypertension (Low sodium)');
      case 'gout':
        return t('Bệnh gút và axit uric cao', 'Gout (Low purine)');
      case 'cholesterol':
        return t('Mỡ máu cao', 'High Cholesterol / Dyslipidemia');
      case 'celiac':
        return t('Không dung nạp đạm lúa mì', 'Celiac Disease (Gluten Intolerance)');
      default:
        return fallback ?? (code ?? '');
    }
  }

  /// Translate scan title to active language
  static String translateScanTitle(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty ||
        v == 'Kết quả quét' ||
        v == 'Scan result' ||
        v == 'Nhãn thực phẩm' ||
        v == 'Food label') {
      return t('Kết quả quét', 'Scan result');
    }
    return v;
  }
}

