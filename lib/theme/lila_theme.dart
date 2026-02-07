import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/focus_state.dart';
import '../models/log_entry.dart';

@immutable
class LilaRadii extends ThemeExtension<LilaRadii> {
  final double small;
  final double medium;
  final double large;

  const LilaRadii({
    required this.small,
    required this.medium,
    required this.large,
  });

  static const builder = LilaRadii(small: 8, medium: 12, large: 20);
  static const sanctuary = LilaRadii(small: 12, medium: 18, large: 26);
  static const explorer = LilaRadii(small: 10, medium: 16, large: 24);
  static const anchor = LilaRadii(small: 6, medium: 10, large: 14);

  @override
  LilaRadii copyWith({double? small, double? medium, double? large}) {
    return LilaRadii(
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
    );
  }

  @override
  LilaRadii lerp(ThemeExtension<LilaRadii>? other, double t) {
    if (other is! LilaRadii) return this;
    return LilaRadii(
      small: lerpDouble(small, other.small, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      large: lerpDouble(large, other.large, t)!,
    );
  }
}

@immutable
class LilaSurface extends ThemeExtension<LilaSurface> {
  /// Primary text color (replaces Colors.white @ 0.8-0.9)
  final Color text;

  /// Secondary text color (replaces Colors.white @ 0.6-0.7)
  final Color textSecondary;

  /// Muted text color (replaces Colors.white @ 0.4-0.5)
  final Color textMuted;

  /// Faint text/icon color (replaces Colors.white @ 0.2-0.35)
  final Color textFaint;

  /// Subtle overlay fills (replaces Colors.white @ 0.05-0.15)
  final Color overlay;

  /// Subtle border color (replaces Colors.white @ 0.1-0.3)
  final Color borderSubtle;

  /// Full contrast foreground (replaces Colors.white @ 1.0)
  final Color foreground;

  /// Shadow color (replaces Colors.black @ various)
  final Color shadow;

  /// Dialog/sheet surface background
  final Color dialogSurface;

  /// Dropdown background
  final Color dropdownSurface;

  const LilaSurface({
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.overlay,
    required this.borderSubtle,
    required this.foreground,
    required this.shadow,
    required this.dialogSurface,
    required this.dropdownSurface,
  });

  static const dark = LilaSurface(
    text: Color(0xCCFFFFFF),           // white @ 0.8
    textSecondary: Color(0x99FFFFFF),   // white @ 0.6
    textMuted: Color(0x66FFFFFF),       // white @ 0.4
    textFaint: Color(0x4DFFFFFF),       // white @ 0.3
    overlay: Color(0x14FFFFFF),         // white @ 0.08
    borderSubtle: Color(0x33FFFFFF),    // white @ 0.2
    foreground: Colors.white,
    shadow: Color(0x1F000000),          // black @ 0.12
    dialogSurface: Color(0xFF1E1E1E),
    dropdownSurface: Color(0xFF2A2A2A),
  );

  static const light = LilaSurface(
    text: Color(0xDD000000),           // black @ 0.87
    textSecondary: Color(0x99000000),   // black @ 0.6
    textMuted: Color(0x66000000),       // black @ 0.4
    textFaint: Color(0x42000000),       // black @ 0.26
    overlay: Color(0x14000000),         // black @ 0.08
    borderSubtle: Color(0x29000000),    // black @ 0.16
    foreground: Color(0xFF1A1A1A),
    shadow: Color(0x1A000000),          // black @ 0.1
    dialogSurface: Color(0xFFF5F5F5),
    dropdownSurface: Color(0xFFEEEEEE),
  );

  @override
  LilaSurface copyWith({
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? overlay,
    Color? borderSubtle,
    Color? foreground,
    Color? shadow,
    Color? dialogSurface,
    Color? dropdownSurface,
  }) {
    return LilaSurface(
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      overlay: overlay ?? this.overlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      foreground: foreground ?? this.foreground,
      shadow: shadow ?? this.shadow,
      dialogSurface: dialogSurface ?? this.dialogSurface,
      dropdownSurface: dropdownSurface ?? this.dropdownSurface,
    );
  }

  @override
  LilaSurface lerp(ThemeExtension<LilaSurface>? other, double t) {
    if (other is! LilaSurface) return this;
    return LilaSurface(
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      dialogSurface: Color.lerp(dialogSurface, other.dialogSurface, t)!,
      dropdownSurface: Color.lerp(dropdownSurface, other.dropdownSurface, t)!,
    );
  }
}

@immutable
class LilaPalette extends ThemeExtension<LilaPalette> {
  final Color nourishment;
  final Color growth;
  final Color maintenance;
  final Color drift;
  final Color decay;
  final Color selfOrientation;
  final Color mutualOrientation;
  final Color otherOrientation;

  const LilaPalette({
    required this.nourishment,
    required this.growth,
    required this.maintenance,
    required this.drift,
    required this.decay,
    required this.selfOrientation,
    required this.mutualOrientation,
    required this.otherOrientation,
  });

  // Dark palettes
  static const builder = LilaPalette(
    nourishment: Color(0xFF5E9E68),
    growth: Color(0xFF5B8FAF),
    maintenance: Color(0xFFC2A84D),
    drift: Color(0xFF8E72B0),
    decay: Color(0xFFD04040),
    selfOrientation: Color(0xFF9B8EC4),
    mutualOrientation: Color(0xFF6BA8A0),
    otherOrientation: Color(0xFFA87B6B),
  );

  static const sanctuary = LilaPalette(
    nourishment: Color(0xFF5E9E68),
    growth: Color(0xFF5B8FAF),
    maintenance: Color(0xFFC2A84D),
    drift: Color(0xFF8E72B0),
    decay: Color(0xFFD04040),
    selfOrientation: Color(0xFFA59AC9),
    mutualOrientation: Color(0xFF7DA79B),
    otherOrientation: Color(0xFFB07A63),
  );

  static const explorer = LilaPalette(
    nourishment: Color(0xFF5E9E68),
    growth: Color(0xFF5B8FAF),
    maintenance: Color(0xFFC2A84D),
    drift: Color(0xFF8E72B0),
    decay: Color(0xFFD04040),
    selfOrientation: Color(0xFFC7A4E6),
    mutualOrientation: Color(0xFFB9948D),
    otherOrientation: Color(0xFFD28B77),
  );

  static const anchor = LilaPalette(
    nourishment: Color(0xFF5E9E68),
    growth: Color(0xFF5B8FAF),
    maintenance: Color(0xFFC2A84D),
    drift: Color(0xFF8E72B0),
    decay: Color(0xFFD04040),
    selfOrientation: Color(0xFF7A8799),
    mutualOrientation: Color(0xFF8793A6),
    otherOrientation: Color(0xFF6E7A8C),
  );

  // Light palettes — deeper/more saturated for contrast on light backgrounds
  static const builderLight = LilaPalette(
    nourishment: Color(0xFF3D7A47),
    growth: Color(0xFF3A6E8E),
    maintenance: Color(0xFF9E8830),
    drift: Color(0xFF6E5290),
    decay: Color(0xFFAA2E2E),
    selfOrientation: Color(0xFF7B6DAA),
    mutualOrientation: Color(0xFF4A8A82),
    otherOrientation: Color(0xFF8A5E4E),
  );

  static const sanctuaryLight = LilaPalette(
    nourishment: Color(0xFF3D7A47),
    growth: Color(0xFF3A6E8E),
    maintenance: Color(0xFF9E8830),
    drift: Color(0xFF6E5290),
    decay: Color(0xFFAA2E2E),
    selfOrientation: Color(0xFF877BAF),
    mutualOrientation: Color(0xFF5C8A7E),
    otherOrientation: Color(0xFF925D46),
  );

  static const explorerLight = LilaPalette(
    nourishment: Color(0xFF3D7A47),
    growth: Color(0xFF3A6E8E),
    maintenance: Color(0xFF9E8830),
    drift: Color(0xFF6E5290),
    decay: Color(0xFFAA2E2E),
    selfOrientation: Color(0xFFA882CC),
    mutualOrientation: Color(0xFF9A7670),
    otherOrientation: Color(0xFFB46D5A),
  );

  static const anchorLight = LilaPalette(
    nourishment: Color(0xFF3D7A47),
    growth: Color(0xFF3A6E8E),
    maintenance: Color(0xFF9E8830),
    drift: Color(0xFF6E5290),
    decay: Color(0xFFAA2E2E),
    selfOrientation: Color(0xFF5A6779),
    mutualOrientation: Color(0xFF677386),
    otherOrientation: Color(0xFF4E5A6C),
  );

  Color modeColor(Mode mode) {
    switch (mode) {
      case Mode.nourishment:
        return nourishment;
      case Mode.growth:
        return growth;
      case Mode.maintenance:
        return maintenance;
      case Mode.drift:
        return drift;
      case Mode.decay:
        return decay;
    }
  }

  Color orientationColor(LogOrientation orientation) {
    switch (orientation) {
      case LogOrientation.self_:
        return selfOrientation;
      case LogOrientation.mutual:
        return mutualOrientation;
      case LogOrientation.other:
        return otherOrientation;
    }
  }

  @override
  LilaPalette copyWith({
    Color? nourishment,
    Color? growth,
    Color? maintenance,
    Color? drift,
    Color? decay,
    Color? selfOrientation,
    Color? mutualOrientation,
    Color? otherOrientation,
  }) {
    return LilaPalette(
      nourishment: nourishment ?? this.nourishment,
      growth: growth ?? this.growth,
      maintenance: maintenance ?? this.maintenance,
      drift: drift ?? this.drift,
      decay: decay ?? this.decay,
      selfOrientation: selfOrientation ?? this.selfOrientation,
      mutualOrientation: mutualOrientation ?? this.mutualOrientation,
      otherOrientation: otherOrientation ?? this.otherOrientation,
    );
  }

  @override
  LilaPalette lerp(ThemeExtension<LilaPalette>? other, double t) {
    if (other is! LilaPalette) return this;
    return LilaPalette(
      nourishment: Color.lerp(nourishment, other.nourishment, t)!,
      growth: Color.lerp(growth, other.growth, t)!,
      maintenance: Color.lerp(maintenance, other.maintenance, t)!,
      drift: Color.lerp(drift, other.drift, t)!,
      decay: Color.lerp(decay, other.decay, t)!,
      selfOrientation: Color.lerp(selfOrientation, other.selfOrientation, t)!,
      mutualOrientation:
          Color.lerp(mutualOrientation, other.mutualOrientation, t)!,
      otherOrientation:
          Color.lerp(otherOrientation, other.otherOrientation, t)!,
    );
  }
}

extension LilaThemeX on BuildContext {
  LilaRadii get lilaRadii =>
      Theme.of(this).extension<LilaRadii>() ?? LilaRadii.builder;
  LilaPalette get lilaPalette =>
      Theme.of(this).extension<LilaPalette>() ?? LilaPalette.builder;
  LilaSurface get lilaSurface =>
      Theme.of(this).extension<LilaSurface>() ?? LilaSurface.dark;
}

class LilaTheme {
  static ThemeData forSeason(FocusSeason season, [Brightness brightness = Brightness.dark]) {
    final isLight = brightness == Brightness.light;
    switch (season) {
      case FocusSeason.builder:
        return _builderTheme(isLight);
      case FocusSeason.sanctuary:
        return _sanctuaryTheme(isLight);
      case FocusSeason.explorer:
        return _explorerTheme(isLight);
      case FocusSeason.anchor:
        return _anchorTheme(isLight);
    }
  }

  static ThemeData _builderTheme(bool isLight) {
    if (isLight) {
      return _buildTheme(
        brightness: Brightness.light,
        scaffold: const Color(0xFFF5F3F0),
        surface: const Color(0xFFFFFFFF),
        surfaceVariant: const Color(0xFFF0EDEA),
        primary: const Color(0xFF527D88),
        secondary: const Color(0xFF8A5E4E),
        tertiary: const Color(0xFFB8962E),
        onSurface: const Color(0xFF1A1A1A),
        onSurfaceVariant: const Color(0xFF5A5A5A),
        outline: const Color(0xFFD5D0CB),
        radii: LilaRadii.builder,
        palette: LilaPalette.builderLight,
        lilaSurface: LilaSurface.light,
        pillFontWeight: FontWeight.w500,
        pillLetterSpacing: 0.1,
      );
    }
    return _buildTheme(
      brightness: Brightness.dark,
      scaffold: const Color(0xFF121212),
      surface: const Color(0xFF1A1A1A),
      surfaceVariant: const Color(0xFF242424),
      primary: const Color(0xFF7B9EA8),
      secondary: const Color(0xFFA87B6B),
      tertiary: const Color(0xFFD6B25E),
      onSurface: const Color(0xFFEDEDED),
      onSurfaceVariant: const Color(0xFFB5B5B5),
      outline: const Color(0xFF3A3A3A),
      radii: LilaRadii.builder,
      palette: LilaPalette.builder,
      lilaSurface: LilaSurface.dark,
      pillFontWeight: FontWeight.w500,
      pillLetterSpacing: 0.1,
    );
  }

  static ThemeData _sanctuaryTheme(bool isLight) {
    if (isLight) {
      return _buildTheme(
        brightness: Brightness.light,
        scaffold: const Color(0xFFF7F3EE),
        surface: const Color(0xFFFCFAF7),
        surfaceVariant: const Color(0xFFF2EDE6),
        primary: const Color(0xFF5A7D62),
        secondary: const Color(0xFF925D46),
        tertiary: const Color(0xFFA89060),
        onSurface: const Color(0xFF2A2118),
        onSurfaceVariant: const Color(0xFF6B5F52),
        outline: const Color(0xFFD6CCBF),
        radii: LilaRadii.sanctuary,
        palette: LilaPalette.sanctuaryLight,
        lilaSurface: LilaSurface.light,
        pillFontWeight: FontWeight.w400,
        pillLetterSpacing: 0.3,
      );
    }
    return _buildTheme(
      brightness: Brightness.dark,
      scaffold: const Color(0xFF1C1A18),
      surface: const Color(0xFF2B2723),
      surfaceVariant: const Color(0xFF3A342F),
      primary: const Color(0xFF6D8570),
      secondary: const Color(0xFFB07A63),
      tertiary: const Color(0xFFC8B07A),
      onSurface: const Color(0xFFEAE3D8),
      onSurfaceVariant: const Color(0xFFB9AEA1),
      outline: const Color(0xFF4B423B),
      radii: LilaRadii.sanctuary,
      palette: LilaPalette.sanctuary,
      lilaSurface: LilaSurface.dark,
      pillFontWeight: FontWeight.w400,
      pillLetterSpacing: 0.3,
    );
  }

  static ThemeData _explorerTheme(bool isLight) {
    if (isLight) {
      return _buildTheme(
        brightness: Brightness.light,
        scaffold: const Color(0xFFF6F2EE),
        surface: const Color(0xFFFCF9F6),
        surfaceVariant: const Color(0xFFF0EAE4),
        primary: const Color(0xFFC27840),
        secondary: const Color(0xFF9468BE),
        tertiary: const Color(0xFFB88370),
        onSurface: const Color(0xFF2A2220),
        onSurfaceVariant: const Color(0xFF6B5E56),
        outline: const Color(0xFFD8CEC6),
        radii: LilaRadii.explorer,
        palette: LilaPalette.explorerLight,
        lilaSurface: LilaSurface.light,
        pillFontWeight: FontWeight.w400,
        pillLetterSpacing: 0.2,
      );
    }
    return _buildTheme(
      brightness: Brightness.dark,
      scaffold: const Color(0xFF1A1616),
      surface: const Color(0xFF1E1A1A),
      surfaceVariant: const Color(0xFF2B2128),
      primary: const Color(0xFFE38B4F),
      secondary: const Color(0xFFB18AD9),
      tertiary: const Color(0xFFD9A48F),
      onSurface: const Color(0xFFE9DDD2),
      onSurfaceVariant: const Color(0xFFC8B9AD),
      outline: const Color(0xFF3D2F3A),
      radii: LilaRadii.explorer,
      palette: LilaPalette.explorer,
      lilaSurface: LilaSurface.dark,
      pillFontWeight: FontWeight.w400,
      pillLetterSpacing: 0.2,
    );
  }

  static ThemeData _anchorTheme(bool isLight) {
    if (isLight) {
      return _buildTheme(
        brightness: Brightness.light,
        scaffold: const Color(0xFFF0F2F6),
        surface: const Color(0xFFF8FAFF),
        surfaceVariant: const Color(0xFFE8ECF2),
        primary: const Color(0xFF7A8DA0),
        secondary: const Color(0xFF5A6B80),
        tertiary: const Color(0xFF6E7F92),
        onSurface: const Color(0xFF1A2030),
        onSurfaceVariant: const Color(0xFF5A6578),
        outline: const Color(0xFFCCD2DC),
        radii: LilaRadii.anchor,
        palette: LilaPalette.anchorLight,
        lilaSurface: LilaSurface.light,
        pillFontWeight: FontWeight.w500,
        pillLetterSpacing: 0.2,
      );
    }
    return _buildTheme(
      brightness: Brightness.dark,
      scaffold: const Color(0xFF141821),
      surface: const Color(0xFF1A202C),
      surfaceVariant: const Color(0xFF242C3A),
      primary: const Color(0xFFA0AEC0),
      secondary: const Color(0xFF718096),
      tertiary: const Color(0xFF8F9BAE),
      onSurface: const Color(0xFFE2E8F0),
      onSurfaceVariant: const Color(0xFFB9C3D1),
      outline: const Color(0xFF4A5568),
      radii: LilaRadii.anchor,
      palette: LilaPalette.anchor,
      lilaSurface: LilaSurface.dark,
      pillFontWeight: FontWeight.w500,
      pillLetterSpacing: 0.2,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color surfaceVariant,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required LilaRadii radii,
    required LilaPalette palette,
    required LilaSurface lilaSurface,
    required FontWeight pillFontWeight,
    required double pillLetterSpacing,
    String fontFamily = 'Roboto',
    List<String> fontFamilyFallback = const [],
  }) {
    final base = ThemeData(
      brightness: brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      useMaterial3: false,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    ).copyWith(
      labelSmall: (base.textTheme.labelSmall ?? const TextStyle(fontSize: 11))
          .copyWith(
        fontWeight: pillFontWeight,
        letterSpacing: pillLetterSpacing,
      ),
    );

    final colorScheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            surface: surface,
            surfaceVariant: surfaceVariant,
            background: scaffold,
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            outline: outline,
          )
        : ColorScheme.light(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            surface: surface,
            surfaceVariant: surfaceVariant,
            background: scaffold,
            onSurface: onSurface,
            onSurfaceVariant: onSurfaceVariant,
            outline: outline,
          );

    final mediumShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.medium),
    );
    final largeShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.large),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: onSurface,
      ),
      iconTheme: IconThemeData(color: onSurface.withValues(alpha: 0.7)),
      dividerColor: onSurface.withValues(alpha: 0.08),
      cardColor: surface,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: mediumShape,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.small),
        ),
        labelStyle: TextStyle(
          color: onSurface.withValues(alpha: 0.75),
          fontSize: 12,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: largeShape,
        backgroundColor: lilaSurface.dialogSurface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radii.large),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.medium),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.medium),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.medium),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        hintStyle: TextStyle(
          color: onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.medium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.large),
        ),
      ),
      extensions: [radii, palette, lilaSurface],
    );
  }
}
