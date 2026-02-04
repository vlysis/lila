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
class LilaPalette extends ThemeExtension<LilaPalette> {
  final Color nourishment;
  final Color growth;
  final Color maintenance;
  final Color drift;
  final Color selfOrientation;
  final Color mutualOrientation;
  final Color otherOrientation;

  const LilaPalette({
    required this.nourishment,
    required this.growth,
    required this.maintenance,
    required this.drift,
    required this.selfOrientation,
    required this.mutualOrientation,
    required this.otherOrientation,
  });

  static const builder = LilaPalette(
    nourishment: Color(0xFF6B8F71),
    growth: Color(0xFF7B9EA8),
    maintenance: Color(0xFFA8976B),
    drift: Color(0xFF8B7B8B),
    selfOrientation: Color(0xFF9B8EC4),
    mutualOrientation: Color(0xFF6BA8A0),
    otherOrientation: Color(0xFFA87B6B),
  );

  static const sanctuary = LilaPalette(
    nourishment: Color(0xFF7C9A84),
    growth: Color(0xFF819B96),
    maintenance: Color(0xFFB4856F),
    drift: Color(0xFF9C8A92),
    selfOrientation: Color(0xFFA59AC9),
    mutualOrientation: Color(0xFF7DA79B),
    otherOrientation: Color(0xFFB07A63),
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
    Color? selfOrientation,
    Color? mutualOrientation,
    Color? otherOrientation,
  }) {
    return LilaPalette(
      nourishment: nourishment ?? this.nourishment,
      growth: growth ?? this.growth,
      maintenance: maintenance ?? this.maintenance,
      drift: drift ?? this.drift,
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
}

class LilaTheme {
  static ThemeData forSeason(FocusSeason season) {
    return season == FocusSeason.sanctuary ? sanctuary : builder;
  }

  static ThemeData get builder {
    return _buildTheme(
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
      pillFontWeight: FontWeight.w500,
      pillLetterSpacing: 0.1,
    );
  }

  static ThemeData get sanctuary {
    return _buildTheme(
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
      pillFontWeight: FontWeight.w400,
      pillLetterSpacing: 0.3,
    );
  }

  static ThemeData _buildTheme({
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
    required FontWeight pillFontWeight,
    required double pillLetterSpacing,
  }) {
    final base = ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
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

    final colorScheme = ColorScheme.dark(
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
      dialogTheme: DialogThemeData(shape: largeShape),
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
      extensions: [radii, palette],
    );
  }
}
