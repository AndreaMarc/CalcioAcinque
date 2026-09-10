// Tema InCampo: token di design (AppTokens), ThemeProvider e buildTheme().
// I colori vivono SOLO qui: fuori da questo file niente Color(0x...).
// Font: Space Grotesk (UI) + Bebas Neue (display) via google_fonts.
// Le preferenze (nome, colori, logo, dark mode) sono per squadra in SharedPreferences.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Design tokens ───
class AppTokens {
  // Brand
  static const Color brand = Color(0xFF00D27F);
  static const Color brandInk = Color(0xFF003D24);
  static const Color brandSoft = Color(0xFFE4FBEE);

  // Surface — light
  static const Color ink = Color(0xFF0A0E0F);
  static const Color ink2 = Color(0xFF151A1C);
  static const Color ink3 = Color(0xFF1F2527);
  static const Color paper = Color(0xFFFAFAF7);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE8E6DF);
  static const Color line2 = Color(0xFFD8D5CC);

  // Text
  static const Color text = Color(0xFF0A0E0F);
  static const Color textMute = Color(0xFF6B6A63);
  static const Color textFaint = Color(0xFF9E9C91);
  static const Color textOnInk = Color(0xFFFFFFFF);
  static const Color textOnInkMute = Color(0xFF9FA7A9);

  // Semantic
  static const Color ok = Color(0xFF00B86B);
  static const Color warn = Color(0xFFE89A2B);
  static const Color bad = Color(0xFFE84A4A);
  static const Color info = Color(0xFF3B7CF2);
  // Semantic: tinta chiara di sfondo + inchiostro leggibile sopra (tema chiaro).
  // In tema scuro si usa semantic.withOpacity(0.15): vedi softOf().
  static const Color okSoft = Color(0xFFDCF6E8);
  static const Color okInk = Color(0xFF096B3A);
  static const Color warnSoft = Color(0xFFFCEDD2);
  static const Color warnInk = Color(0xFF8A5510);
  static const Color badSoft = Color(0xFFFCE0E0);
  static const Color badInk = Color(0xFF9E2323);
  // Accenti particolari
  static const Color guest = Color(0xFF9D6BFF);     // ospite / amico / in attesa
  static const Color live = Color(0xFFFF3838);      // pallino LIVE
  static const Color away = Color(0xFFFF5252);      // eventi della squadra avversaria
  static const Color brandGlow = Color(0xFF00FFA6); // anello luminoso StoryAvatar
  static const Color inkShadow = Color(0x1A0A0E0F); // ombra delle card scure

  // Surface tiers (chiaro) / (scuro)
  static const Color paperLow = Color(0xFFF2F0EA);
  static const Color paperHigh = Color(0xFFF6F4EE);
  static const Color paperHighest = Color(0xFFEEECE4);
  static const Color darkPaperLow = Color(0xFF0F1314);

  // Dark surfaces
  static const Color darkBrand = Color(0xFF00E88C);
  static const Color darkPaper = Color(0xFF0A0E0F);
  static const Color darkCard = Color(0xFF151A1C);
  static const Color darkLine = Color(0xFF242A2C);
  static const Color darkText = Color(0xFFF5F5F2);
  static const Color darkTextMute = Color(0xFF8A908E);

  // Radii
  static const double rCard = 20;
  static const double rCardLg = 24;
  static const double rButton = 14;
  static const double rChip = 999;
  static const double rInput = 14;

  /// Tinta di sfondo per uno stato semantico, coerente tra tema chiaro e scuro.
  static Color softOf(Color semantic, {required bool isDark}) {
    if (isDark) return semantic.withOpacity(0.15);
    if (semantic == ok) return okSoft;
    if (semantic == warn) return warnSoft;
    if (semantic == bad) return badSoft;
    if (semantic == brand) return brandSoft;
    return semantic.withOpacity(0.12);
  }

  // Typography — Space Grotesk (UI), Bebas Neue (display/numbers)
  static TextTheme buildTextTheme(Brightness b, Color textColor, Color muteColor) {
    final ui = GoogleFonts.spaceGroteskTextTheme();
    final display = GoogleFonts.bebasNeue();

    return ui.copyWith(
      // Display — Bebas Neue, condensed sporty
      displayLarge:  display.copyWith(fontSize: 64, height: 0.88, letterSpacing: 0.01, color: textColor),
      displayMedium: display.copyWith(fontSize: 48, height: 0.92, letterSpacing: 0.01, color: textColor),
      displaySmall:  display.copyWith(fontSize: 36, height: 0.95, letterSpacing: 0.02, color: textColor),
      headlineLarge: display.copyWith(fontSize: 32, height: 1.0,  letterSpacing: 0.02, color: textColor),
      headlineMedium:display.copyWith(fontSize: 26, height: 1.05, letterSpacing: 0.02, color: textColor),
      headlineSmall: display.copyWith(fontSize: 22, height: 1.1,  letterSpacing: 0.02, color: textColor),
      // Title/body — Space Grotesk
      titleLarge:  ui.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 18, letterSpacing: -0.01, color: textColor),
      titleMedium: ui.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
      titleSmall:  ui.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
      bodyLarge:  ui.bodyLarge?.copyWith(fontSize: 15, height: 1.4, color: textColor),
      bodyMedium: ui.bodyMedium?.copyWith(fontSize: 14, height: 1.4, color: textColor),
      bodySmall:  ui.bodySmall?.copyWith(fontSize: 12, height: 1.35, color: muteColor),
      labelLarge:  ui.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.02, color: textColor),
      labelMedium: ui.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.14, color: muteColor),
      labelSmall:  ui.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.14, color: muteColor),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  static const String _legacyKeyTeamName = 'team_name';
  static const String _legacyKeyPrimaryColor = 'primary_color';
  static const String _legacyKeyAccentColor = 'accent_color';
  static const String _legacyKeyLogoBase64 = 'team_logo_base64';
  static const String _keyDarkMode = 'dark_mode';
  // Chiave usata dalle versioni precedenti: letta solo come fallback.
  static const String _legacyKeyDarkMode = 'gimmy_dark_mode';

  int? _currentTeamId;
  String _teamName = 'InCampo';
  // Default brand = InCampo electric pitch green (was verde scuro 0xFF1B5E20)
  Color _primaryColor = AppTokens.brand;
  Color _accentColor = AppTokens.ink;
  String? _logoBase64;
  // Bytes del logo decodificati UNA volta: MemoryImage confronta i bytes per
  // identita', un nuovo Uint8List a ogni build farebbe ridecodificare l'immagine
  // a ogni frame.
  Uint8List? _logoBytes;
  SharedPreferences? _prefs;
  final Map<int, Uint8List?> _teamLogoCache = {};
  bool _dark = false;

  String get teamName => _teamName;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  String? get logoBase64 => _logoBase64;
  bool get hasLogo => _logoBase64 != null && _logoBase64!.isNotEmpty;
  int? get currentTeamId => _currentTeamId;
  bool get isDark => _dark;

  Uint8List? get logoBytes => _logoBytes;

  /// Logo salvato su questo browser per una squadra qualsiasi (non solo quella
  /// attiva): serve alle liste di squadre. `null` se non c'e' o non e' ancora
  /// stato caricato nulla da SharedPreferences.
  Uint8List? logoBytesForTeam(int teamId) {
    if (teamId == _currentTeamId) return _logoBytes;
    if (_teamLogoCache.containsKey(teamId)) return _teamLogoCache[teamId];
    final prefs = _prefs;
    if (prefs == null) return null;
    final bytes = _decode(prefs.getString('team_${teamId}_logo_base64'));
    _teamLogoCache[teamId] = bytes;
    return bytes;
  }

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  ThemeProvider() {
    _loadPreferences();
  }

  String _keyTeamName() => _currentTeamId != null
      ? 'team_${_currentTeamId}_name' : _legacyKeyTeamName;
  String _keyPrimaryColor() => _currentTeamId != null
      ? 'team_${_currentTeamId}_primary_color' : _legacyKeyPrimaryColor;
  String _keyAccentColor() => _currentTeamId != null
      ? 'team_${_currentTeamId}_accent_color' : _legacyKeyAccentColor;
  String _keyLogoBase64() => _currentTeamId != null
      ? 'team_${_currentTeamId}_logo_base64' : _legacyKeyLogoBase64;

  Future<void> setCurrentTeamId(int? teamId) async {
    if (_currentTeamId == teamId) return;
    _currentTeamId = teamId;
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _teamName = prefs.getString(_keyTeamName()) ?? 'InCampo';
    final primaryValue = prefs.getInt(_keyPrimaryColor());
    _primaryColor = primaryValue != null ? Color(primaryValue) : AppTokens.brand;
    final accentValue = prefs.getInt(_keyAccentColor());
    _accentColor = accentValue != null ? Color(accentValue) : AppTokens.ink;
    _prefs = prefs;
    _logoBase64 = prefs.getString(_keyLogoBase64());
    _logoBytes = _decode(_logoBase64);
    _dark = prefs.getBool(_keyDarkMode) ?? prefs.getBool(_legacyKeyDarkMode) ?? false;
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
    _logoBytes = bytes;
    if (_currentTeamId != null) _teamLogoCache[_currentTeamId!] = bytes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoBase64(), _logoBase64!);
    notifyListeners();
  }

  Future<void> removeLogo() async {
    _logoBase64 = null;
    _logoBytes = null;
    if (_currentTeamId != null) _teamLogoCache.remove(_currentTeamId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogoBase64());
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _dark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }

  // ─── Build the actual InCampo theme ───
  ThemeData buildTheme({bool? dark}) {
    final isDark = dark ?? _dark;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    final Color brand = isDark ? AppTokens.darkBrand : _primaryColor;
    final Color paper = isDark ? AppTokens.darkPaper : AppTokens.paper;
    final Color card  = isDark ? AppTokens.darkCard  : AppTokens.card;
    final Color line  = isDark ? AppTokens.darkLine  : AppTokens.line;
    final Color text  = isDark ? AppTokens.darkText  : AppTokens.text;
    final Color mute  = isDark ? AppTokens.darkTextMute : AppTokens.textMute;
    final Color onBrand = isDark ? AppTokens.brandInk : AppTokens.brandInk;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: onBrand,
      primaryContainer: isDark ? AppTokens.darkBrand.withOpacity(0.18) : AppTokens.brandSoft,
      onPrimaryContainer: isDark ? AppTokens.darkBrand : AppTokens.brandInk,
      secondary: isDark ? Colors.white : AppTokens.ink,
      onSecondary: isDark ? AppTokens.ink : Colors.white,
      secondaryContainer: isDark ? AppTokens.ink3 : AppTokens.ink,
      onSecondaryContainer: Colors.white,
      tertiary: AppTokens.warn,
      onTertiary: Colors.white,
      tertiaryContainer: AppTokens.softOf(AppTokens.warn, isDark: isDark),
      onTertiaryContainer: AppTokens.warnInk,
      error: AppTokens.bad,
      onError: Colors.white,
      errorContainer: AppTokens.softOf(AppTokens.bad, isDark: isDark),
      onErrorContainer: AppTokens.badInk,
      surface: paper,
      onSurface: text,
      surfaceContainerLowest: paper,
      surfaceContainerLow: isDark ? AppTokens.darkPaperLow : AppTokens.paperLow,
      surfaceContainer: card,
      surfaceContainerHigh: isDark ? AppTokens.ink3 : AppTokens.paperHigh,
      surfaceContainerHighest: isDark ? AppTokens.ink3 : AppTokens.paperHighest,
      onSurfaceVariant: mute,
      outline: line,
      outlineVariant: line.withOpacity(0.5),
      shadow: Colors.black,
      scrim: Colors.black.withOpacity(0.5),
      inverseSurface: isDark ? paper : AppTokens.ink,
      onInverseSurface: isDark ? text : Colors.white,
      inversePrimary: brand,
    );

    final textTheme = AppTokens.buildTextTheme(brightness, text, mute);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: textTheme,
      canvasColor: paper,
      dividerColor: line,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rCard),
          side: BorderSide(color: line),
        ),
        color: card,
        surfaceTintColor: Colors.transparent,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppTokens.darkPaperLow : AppTokens.paperLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rInput),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rInput),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rInput),
          borderSide: BorderSide(color: brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rInput),
          borderSide: BorderSide(color: AppTokens.bad),
        ),
        labelStyle: TextStyle(color: mute),
        hintStyle: TextStyle(color: mute.withOpacity(0.7)),
        prefixIconColor: mute,
        suffixIconColor: mute,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rButton),
          ),
          elevation: 0,
          backgroundColor: isDark ? Colors.white : AppTokens.ink,
          foregroundColor: isDark ? AppTokens.ink : Colors.white,
          disabledBackgroundColor: (isDark ? Colors.white : AppTokens.ink).withOpacity(0.3),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rButton),
          ),
          backgroundColor: brand,
          foregroundColor: onBrand,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: line, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rButton),
          ),
          foregroundColor: text,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: brand,
        foregroundColor: onBrand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppTokens.ink3 : card,
        side: BorderSide(color: line),
        labelStyle: textTheme.labelMedium?.copyWith(fontSize: 11, letterSpacing: 0.02, color: mute),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rChip),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? card : AppTokens.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
      ),

      dialogTheme: DialogTheme(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rCardLg)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: line,
      ),

      tabBarTheme: TabBarTheme(
        labelColor: text,
        unselectedLabelColor: mute,
        indicatorColor: brand,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onBrand : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? brand : line,
        ),
      ),
    );
  }

  // Preset palettes — InCampo curated (restyle defaults)
  static const List<Color> availableColors = [
    Color(0xFF00D27F), // InCampo brand — electric pitch green (default)
    Color(0xFF0A0E0F), // Near-black
    Color(0xFF3B7CF2), // Electric blue
    Color(0xFFE84A4A), // Signal red
    Color(0xFFE89A2B), // Ochre
    Color(0xFF7C3AED), // Violet
    Color(0xFF0EA5A5), // Teal
    Color(0xFFEC4899), // Pink
    Color(0xFF1B5E20), // Legacy verde scuro (kept for teams already on it)
    Color(0xFF0D47A1), // Legacy blu scuro
  ];

  static const List<Color> availableAccentColors = [
    Color(0xFF0A0E0F), // Ink
    Color(0xFFFFFFFF), // Paper
    Color(0xFFFFC107), // Amber (legacy)
    Color(0xFF3B7CF2), // Blue
    Color(0xFFE84A4A), // Red
  ];
}
