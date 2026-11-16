import 'package:flutter/material.dart';

/// Paleta clara, mantida como referência para os tokens fixos.
class AppColors {
  static const cream = Color(0xFFF7F5EF);
  static const surface = Colors.white;
  static const ink = Color(0xFF1F241B);
  // Escurecido de 0xFF7C8275 (3.6:1) para 0xFF5C6355 (5.7:1 sobre cream).
  static const muted = Color(0xFF5C6355);
  static const line = Color(0xFFECE9E0);

  static const green = Color(0xFF4C7A1F);
  static const greenDark = Color(0xFF33560F);
  static const greenSoft = Color(0xFFE9F1DC);

  // Escurecido de 0xFFE4572E (3.1:1 sobre coralSoft) para 0xFFC2411F (4.4:1).
  static const coral = Color(0xFFC2411F);
  static const coralSoft = Color(0xFFFCE9E2);

  static const protein = Color(0xFF1D4ED8); // Era 0xFF2F6FED
  static const proteinSoft = Color(0xFFE4ECFD);
  static const carbs = Color(0xFF8A4B00); // Era 0xFFEE9B2E
  static const carbsSoft = Color(0xFFFDF0DC);
  static const fat = Color(0xFF6D2BA8); // Era 0xFF9B51E0
  static const fatSoft = Color(0xFFF2E6FB);

  static const water = Color(0xFF1565A8);
  static const waterSoft = Color(0xFFE3F0FA);
  static const onWater = Colors.white;
}

const kProteinColor = AppColors.protein;
const kCarbsColor = AppColors.carbs;
const kFatColor = AppColors.fat;

/// Paleta resolvida em tempo de execução, de acordo com o tema ativo.
///
/// Os widgets do app leem as cores por aqui (`context.colors`) em vez de
/// usar os valores fixos de [AppColors]. É isso que faz o modo escuro
/// trocar fundo, cards, textos e acentos de forma consistente.
@immutable
class NutriaColors extends ThemeExtension<NutriaColors> {
  const NutriaColors({
    required this.cream,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.green,
    required this.greenDark,
    required this.greenSoft,
    required this.onGreen,
    required this.coral,
    required this.coralSoft,
    required this.protein,
    required this.proteinSoft,
    required this.carbs,
    required this.carbsSoft,
    required this.fat,
    required this.fatSoft,
    required this.water,
    required this.waterSoft,
    required this.onWater,
  });

  final Color cream;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color green;
  final Color greenDark;
  final Color greenSoft;
  final Color onGreen;
  final Color coral;
  final Color coralSoft;
  final Color protein;
  final Color proteinSoft;
  final Color carbs;
  final Color carbsSoft;
  final Color fat;
  final Color fatSoft;
  final Color water;
  final Color waterSoft;
  final Color onWater;

  static const light = NutriaColors(
    cream: AppColors.cream,
    surface: AppColors.surface,
    ink: AppColors.ink,
    muted: AppColors.muted,
    line: AppColors.line,
    green: AppColors.green,
    greenDark: AppColors.greenDark,
    greenSoft: AppColors.greenSoft,
    onGreen: Colors.white,
    coral: AppColors.coral,
    coralSoft: AppColors.coralSoft,
    protein: AppColors.protein,
    proteinSoft: AppColors.proteinSoft,
    carbs: AppColors.carbs,
    carbsSoft: AppColors.carbsSoft,
    fat: AppColors.fat,
    fatSoft: AppColors.fatSoft,
    water: AppColors.water,
    waterSoft: AppColors.waterSoft,
    onWater: AppColors.onWater,
  );

  /// Verde-oliva profundo com acentos mais claros para manter contraste.
  static const dark = NutriaColors(
    cream: Color(0xFF10130E),
    surface: Color(0xFF1A1E17),
    ink: Color(0xFFF2F0E7),
    muted: Color(0xFFA7AD9F),
    line: Color(0xFF2C3128),
    green: Color(0xFFA6D65F),
    greenDark: Color(0xFF7FAE3D),
    greenSoft: Color(0xFF232C18),
    onGreen: Color(0xFF15200A),
    coral: Color(0xFFFF9D7B),
    coralSoft: Color(0xFF36221B),
    protein: Color(0xFF93B7FF),
    proteinSoft: Color(0xFF1B2538),
    carbs: Color(0xFFF2BC72),
    carbsSoft: Color(0xFF322510),
    fat: Color(0xFFCBA0F0),
    fatSoft: Color(0xFF2A1F37),
    water: Color(0xFF7CC4FF),
    waterSoft: Color(0xFF132431),
    onWater: Color(0xFF0A1A24),
  );

  @override
  NutriaColors copyWith({
    Color? cream,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? green,
    Color? greenDark,
    Color? greenSoft,
    Color? onGreen,
    Color? coral,
    Color? coralSoft,
    Color? protein,
    Color? proteinSoft,
    Color? carbs,
    Color? carbsSoft,
    Color? fat,
    Color? fatSoft,
    Color? water,
    Color? waterSoft,
    Color? onWater,
  }) {
    return NutriaColors(
      cream: cream ?? this.cream,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      green: green ?? this.green,
      greenDark: greenDark ?? this.greenDark,
      greenSoft: greenSoft ?? this.greenSoft,
      onGreen: onGreen ?? this.onGreen,
      coral: coral ?? this.coral,
      coralSoft: coralSoft ?? this.coralSoft,
      protein: protein ?? this.protein,
      proteinSoft: proteinSoft ?? this.proteinSoft,
      carbs: carbs ?? this.carbs,
      carbsSoft: carbsSoft ?? this.carbsSoft,
      fat: fat ?? this.fat,
      fatSoft: fatSoft ?? this.fatSoft,
      water: water ?? this.water,
      waterSoft: waterSoft ?? this.waterSoft,
      onWater: onWater ?? this.onWater,
    );
  }

  @override
  NutriaColors lerp(NutriaColors? other, double t) {
    if (other == null) return this;
    return NutriaColors(
      cream: Color.lerp(cream, other.cream, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenDark: Color.lerp(greenDark, other.greenDark, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
      onGreen: Color.lerp(onGreen, other.onGreen, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralSoft: Color.lerp(coralSoft, other.coralSoft, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      proteinSoft: Color.lerp(proteinSoft, other.proteinSoft, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      carbsSoft: Color.lerp(carbsSoft, other.carbsSoft, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      fatSoft: Color.lerp(fatSoft, other.fatSoft, t)!,
      water: Color.lerp(water, other.water, t)!,
      waterSoft: Color.lerp(waterSoft, other.waterSoft, t)!,
      onWater: Color.lerp(onWater, other.onWater, t)!,
    );
  }
}

/// Atalho para a paleta do tema atual.
extension NutriaColorsX on BuildContext {
  NutriaColors get colors =>
      Theme.of(this).extension<NutriaColors>() ?? NutriaColors.light;
}

ThemeData buildAppTheme() => _buildTheme(Brightness.light, NutriaColors.light);

/// Tema escuro, com a mesma estrutura de componentes do tema claro.
ThemeData buildDarkAppTheme() => _buildTheme(Brightness.dark, NutriaColors.dark);

ThemeData _buildTheme(Brightness brightness, NutriaColors c) {
  final isDark = brightness == Brightness.dark;

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.green,
      brightness: brightness,
    ).copyWith(
      primary: c.green,
      onPrimary: c.onGreen,
      secondary: c.coral,
      onSecondary: isDark ? const Color(0xFF2A130C) : Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      outlineVariant: c.line,
    ),
    scaffoldBackgroundColor: c.cream,
  );

  return base.copyWith(
    extensions: [c],
    textTheme: base.textTheme.copyWith(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.8,
        color: c.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        color: c.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: c.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: c.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.35, color: c.muted),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: c.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: c.ink,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(color: c.muted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: isDark ? BorderSide(color: c.line) : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: isDark ? BorderSide(color: c.line) : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: c.green, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.green,
        foregroundColor: c.onGreen,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.green,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? c.surface : c.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        color: isDark ? c.ink : Colors.white,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line),
  );
}

/// Sombra suave usada nos cards flutuantes.
const kSoftShadow = [
  BoxShadow(
    color: Color(0x0D1F241B),
    blurRadius: 24,
    offset: Offset(0, 10),
  ),
];
