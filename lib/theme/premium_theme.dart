import 'dart:ui';
import 'package:flutter/material.dart';
export '../widgets/app_logo.dart';

class AppColors {
  // 60-30-10 Palette based on User provided colors
  static const Color paletteLight = Color(0xFFADE1FB);   // Lightest Blue (60% background / frost)
  static const Color paletteMedium = Color(0xFF266CA9);  // Medium Blue (30% secondary / cards / borders)
  static const Color paletteDark = Color(0xFF0F2573);    // Dark Royal Blue (10% accent)
  static const Color paletteNavy = Color(0xFF041D56);    // Dark Navy (10% accent)
  static const Color paletteMidnight = Color(0xFF01082D);// Midnight Blue (10% accent / text)

  // Brand Colors mapping
  static const Color primary = paletteMedium;     
  static const Color secondary = paletteDark;     
  static const Color tertiary = paletteLight;     
  static const Color navy = paletteNavy;          
  static const Color darkBg = paletteMidnight;

  // Background & Surface (60% Dominant & 30% Secondary)
  static const Color scaffold = Color(0xFFF2F9FF); // Soft frost background
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  // Glassmorphism (30%)
  static Color glassBackground = Colors.white.withValues(alpha: 0.82);
  static Color glassBorder = Colors.white.withValues(alpha: 0.5);

  // Functional
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color slate = Color(0xFF64748B);
  static const Color darkText = paletteMidnight;
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = paletteDark;
  static const Color subTextLight = Color(0xFF64748B);
  static const Color subTextDark = Color(0xFF94A3B8);
}

class AppGradients {
  static const LinearGradient ocean = LinearGradient(
    colors: [AppColors.paletteNavy, AppColors.paletteMedium],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient electric = LinearGradient(
    colors: [AppColors.paletteMedium, AppColors.paletteDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeader = LinearGradient(
    colors: [AppColors.paletteMidnight, AppColors.paletteNavy, AppColors.paletteDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 60% Dominant Background Gradient based on Lightest Blue (#ADE1FB)
  static const LinearGradient mainBackground = LinearGradient(
    colors: [Color(0xFFF8FCFF), Color(0xFFEAF5FE), AppColors.paletteLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AquaTheme {
  static ThemeData get light {
    return ThemeData(
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: Colors.white,
        outline: AppColors.borderLight,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.scaffold,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.secondary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.secondary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.subTextLight, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.subTextLight, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.paletteMedium,
        secondary: AppColors.paletteLight,
        surface: AppColors.paletteNavy,
        onSurface: Colors.white,
        outline: AppColors.borderDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1.2),
        ),
        color: AppColors.paletteNavy,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paletteMidnight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.paletteLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.subTextDark, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.subTextDark, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.paletteMedium,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          elevation: 3,
          shadowColor: AppColors.paletteMedium.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.color,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final glassColor = color ?? (isDark
        ? AppColors.paletteNavy.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.80));

    final glassBorder = border ??
        Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.90),
          width: 1.5,
        );

    Widget content = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: glassBorder,
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppColors.paletteMedium.withValues(alpha: 0.15),
                        AppColors.paletteMidnight.withValues(alpha: 0.40),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.85),
                        AppColors.paletteLight.withValues(alpha: 0.30),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.paletteMedium.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}

class LiquidButton extends StatelessWidget {
  final String? text;
  final String? label;
  final VoidCallback? onPressed;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final Gradient? gradient;
  final double height;
  final double borderRadius;

  const LiquidButton({
    super.key,
    this.text,
    this.label,
    this.onPressed,
    this.onTap,
    this.isLoading = false,
    this.icon,
    this.color,
    this.gradient,
    this.height = 54,
    this.borderRadius = 16,
  });

  String get buttonText => text ?? label ?? '';
  VoidCallback? get buttonAction => onPressed ?? onTap;

  @override
  Widget build(BuildContext context) {
    final bgGradient = gradient ?? AppGradients.ocean;
    final action = buttonAction;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: action == null ? null : bgGradient,
        color: action == null ? Colors.grey.shade400 : (color ?? AppColors.paletteMedium),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: action == null
            ? null
            : [
                BoxShadow(
                  color: AppColors.paletteMedium.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : action,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
