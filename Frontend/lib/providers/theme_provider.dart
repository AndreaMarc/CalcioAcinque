import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Legacy keys (used as fallback when no teamId set)
  static const String _legacyKeyTeamName = 'team_name';
  static const String _legacyKeyPrimaryColor = 'primary_color';
  static const String _legacyKeyAccentColor = 'accent_color';
  static const String _legacyKeyLogoBase64 = 'team_logo_base64';

  int? _currentTeamId;
  String _teamName = 'Calcio a 5';
  Color _primaryColor = const Color(0xFF1B5E20); // verde scuro
  Color _accentColor = const Color(0xFFFFC107); // amber
  String? _logoBase64;

  String get teamName => _teamName;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  String? get logoBase64 => _logoBase64;
  bool get hasLogo => _logoBase64 != null && _logoBase64!.isNotEmpty;
  int? get currentTeamId => _currentTeamId;

  Uint8List? get logoBytes {
    if (_logoBase64 == null || _logoBase64!.isEmpty) return null;
    try {
      return base64Decode(_logoBase64!);
    } catch (_) {
      return null;
    }
  }

  ThemeProvider() {
    _loadPreferences();
  }

  String _keyTeamName() => _currentTeamId != null
      ? 'team_${_currentTeamId}_name'
      : _legacyKeyTeamName;

  String _keyPrimaryColor() => _currentTeamId != null
      ? 'team_${_currentTeamId}_primary_color'
      : _legacyKeyPrimaryColor;

  String _keyAccentColor() => _currentTeamId != null
      ? 'team_${_currentTeamId}_accent_color'
      : _legacyKeyAccentColor;

  String _keyLogoBase64() => _currentTeamId != null
      ? 'team_${_currentTeamId}_logo_base64'
      : _legacyKeyLogoBase64;

  Future<void> setCurrentTeamId(int? teamId) async {
    if (_currentTeamId == teamId) return;
    _currentTeamId = teamId;
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _teamName = prefs.getString(_keyTeamName()) ?? 'Calcio a 5';
    final primaryValue = prefs.getInt(_keyPrimaryColor());
    if (primaryValue != null) {
      _primaryColor = Color(primaryValue);
    } else {
      _primaryColor = const Color(0xFF1B5E20);
    }
    final accentValue = prefs.getInt(_keyAccentColor());
    if (accentValue != null) {
      _accentColor = Color(accentValue);
    } else {
      _accentColor = const Color(0xFFFFC107);
    }
    _logoBase64 = prefs.getString(_keyLogoBase64());
    notifyListeners();
  }

  Future<void> setTeamName(String name) async {
    _teamName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTeamName(), name);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPrimaryColor(), color.value);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor(), color.value);
    notifyListeners();
  }

  Future<void> setLogo(Uint8List bytes) async {
    _logoBase64 = base64Encode(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoBase64(), _logoBase64!);
    notifyListeners();
  }

  Future<void> removeLogo() async {
    _logoBase64 = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogoBase64());
    notifyListeners();
  }

  ThemeData buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      secondary: _accentColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        color: colorScheme.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.3),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Colori predefiniti disponibili
  static const List<Color> availableColors = [
    Color(0xFF1B5E20), // Verde scuro
    Color(0xFF0D47A1), // Blu scuro
    Color(0xFFB71C1C), // Rosso scuro
    Color(0xFF1A237E), // Indaco
    Color(0xFF004D40), // Teal scuro
    Color(0xFF311B92), // Viola scuro
    Color(0xFFE65100), // Arancione scuro
    Color(0xFF263238), // Grigio blu
    Color(0xFF880E4F), // Rosa scuro
    Color(0xFF33691E), // Lime scuro
  ];

  static const List<Color> availableAccentColors = [
    Color(0xFFFFC107), // Amber
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF00BCD4), // Cyan
    Color(0xFF4CAF50), // Green
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF03A9F4), // Light Blue
    Color(0xFFCDDC39), // Lime
    Color(0xFFF44336), // Red
  ];
}
