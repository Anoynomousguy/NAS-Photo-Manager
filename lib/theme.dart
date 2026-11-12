import 'package:flutter/material.dart';

/// Exact color tokens of the OneDrive mobile design language (light / dark).
abstract final class OneDriveColors {
  // Brand.
  static const Color primaryLight = Color(0xFF0F6CBD);
  static const Color primaryDark = Color(0xFF479EF5);

  // Surfaces.
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF292929);
  static const Color surfaceContainerLight = Color(0xFFFAFAFA);
  static const Color surfaceContainerDark = Color(0xFF1F1F1F);
  static const Color surfaceContainerHighestLight = Color(0xFFF5F5F5);
  static const Color surfaceContainerHighestDark = Color(0xFF141414);

  // Selected (navigation indicator).
  static const Color selectedLight = Color(0xFFEBEBEB);
  static const Color selectedDark = Color(0xFF383838);

  // Text.
  static const Color onSurfaceLight = Color(0xFF242424);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color onSurfaceVariantLight = Color(0xFF424242);
  static const Color onSurfaceVariantDark = Color(0xFFD6D6D6);
  static const Color secondaryTextLight = Color(0xFF616161);
  static const Color secondaryTextDark = Color(0xFFADADAD);

  // Lines and status.
  static const Color outlineVariantLight = Color(0xFFE0E0E0);
  static const Color outlineVariantDark = Color(0xFF525252);
  static const Color error = Color(0xFFC50F1F);

  // Accents.
  static const Color folderAmber = Color(0xFFFFB900);
}

/// Extra OneDrive tokens that have no direct Material slot.
@immutable
class OneDriveTokens extends ThemeExtension<OneDriveTokens> {
  const OneDriveTokens({
    required this.brightness,
    required this.secondaryText,
    required this.selection,
    required this.folderIcon,
  });

  static const OneDriveTokens light = OneDriveTokens(
    brightness: Brightness.light,
    secondaryText: OneDriveColors.secondaryTextLight,
    selection: OneDriveColors.selectedLight,
    folderIcon: OneDriveColors.folderAmber,
  );

  static const OneDriveTokens dark = OneDriveTokens(
    brightness: Brightness.dark,
    secondaryText: OneDriveColors.secondaryTextDark,
    selection: OneDriveColors.selectedDark,
    folderIcon: OneDriveColors.folderAmber,
  );

  static OneDriveTokens of(BuildContext context) =>
      Theme.of(context).extension<OneDriveTokens>() ?? light;

  final Brightness brightness;
  final Color secondaryText;
  final Color selection;
  final Color folderIcon;

  @override
  OneDriveTokens copyWith({
    Brightness? brightness,
    Color? secondaryText,
    Color? selection,
    Color? folderIcon,
  }) {
    return OneDriveTokens(
      brightness: brightness ?? this.brightness,
      secondaryText: secondaryText ?? this.secondaryText,
      selection: selection ?? this.selection,
      folderIcon: folderIcon ?? this.folderIcon,
    );
  }

  @override
  OneDriveTokens lerp(
    covariant ThemeExtension<OneDriveTokens>? other,
    double t,
  ) {
    if (other is! OneDriveTokens) return this;
    return OneDriveTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      folderIcon: Color.lerp(folderIcon, other.folderIcon, t)!,
    );
  }
}

/// Light and dark Material 3 themes seeded from the OneDrive brand blue and
/// pinned to the exact OneDrive surface and text tokens.
abstract final class OneDriveTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final OneDriveTokens tokens = isDark
        ? OneDriveTokens.dark
        : OneDriveTokens.light;

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: isDark
              ? OneDriveColors.primaryDark
              : OneDriveColors.primaryLight,
          brightness: brightness,
        ).copyWith(
          primary: isDark
              ? OneDriveColors.primaryDark
              : OneDriveColors.primaryLight,
          onPrimary: isDark ? const Color(0xFF002F4D) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF0B3A5C)
              : const Color(0xFFDCEEFF),
          onPrimaryContainer: isDark
              ? const Color(0xFFC8E6FF)
              : const Color(0xFF063A63),
          secondary: isDark
              ? const Color(0xFF75D1C4)
              : const Color(0xFF006A61),
          onSecondary: isDark ? const Color(0xFF00332E) : Colors.white,
          tertiary: isDark
              ? const Color(0xFFFFC66B)
              : const Color(0xFF7A5900),
          surface: isDark
              ? OneDriveColors.surfaceDark
              : OneDriveColors.surfaceLight,
          surfaceContainerLow: isDark
              ? const Color(0xFF242424)
              : const Color(0xFFFCFCFC),
          surfaceContainer: isDark
              ? OneDriveColors.surfaceContainerDark
              : OneDriveColors.surfaceContainerLight,
          surfaceContainerHigh: isDark
              ? const Color(0xFF333333)
              : const Color(0xFFF7F7F7),
          surfaceContainerHighest: isDark
              ? OneDriveColors.surfaceContainerHighestDark
              : OneDriveColors.surfaceContainerHighestLight,
          onSurface: isDark
              ? OneDriveColors.onSurfaceDark
              : OneDriveColors.onSurfaceLight,
          onSurfaceVariant: isDark
              ? OneDriveColors.onSurfaceVariantDark
              : OneDriveColors.onSurfaceVariantLight,
          outlineVariant: isDark
              ? OneDriveColors.outlineVariantDark
              : OneDriveColors.outlineVariantLight,
          error: OneDriveColors.error,
          errorContainer: isDark
              ? const Color(0xFF5C1A1F)
              : const Color(0xFFFFE5E7),
          onErrorContainer: isDark
              ? const Color(0xFFFFB3B8)
              : const Color(0xFF6B1118),
          surfaceTint: Colors.transparent,
        );

    final ThemeData base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    // File names 16/24, metadata 13 secondary, section titles 20-22.
    final TextTheme textTheme = base.textTheme.copyWith(
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        color: tokens.secondaryText,
      ),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        color: tokens.secondaryText,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 14 / 11,
        color: tokens.secondaryText,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 58,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.selection,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
        height: 70,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: OneDrivePageTransitionsBuilder(),
          TargetPlatform.iOS: OneDrivePageTransitionsBuilder(),
          TargetPlatform.linux: OneDrivePageTransitionsBuilder(),
          TargetPlatform.macOS: OneDrivePageTransitionsBuilder(),
          TargetPlatform.windows: OneDrivePageTransitionsBuilder(),
        },
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          overlayColor: WidgetStatePropertyAll<Color>(
            scheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFF5F5F5)
            : const Color(0xFF242424),
        contentTextStyle: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          color: isDark ? const Color(0xFF242424) : Colors.white,
        ),
        actionTextColor: isDark
            ? OneDriveColors.primaryLight
            : OneDriveColors.primaryDark,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF242424) : Colors.white,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        extendedTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(fontSize: 14, color: scheme.onSurface),
      ),
      inputDecorationTheme: _inputDecorationTheme(scheme, tokens),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static InputDecorationThemeData _inputDecorationTheme(
    ColorScheme scheme,
    OneDriveTokens tokens,
  ) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return InputDecorationThemeData(
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
      hintStyle: TextStyle(color: tokens.secondaryText, fontSize: 14),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontSize: 14),
    );
  }
}

/// A restrained fade-and-lift transition for pushed surfaces (Settings,
/// Tutorial, image viewer). It keeps navigation feeling connected rather than
/// dropping a new page on top of the old one.
class OneDrivePageTransitionsBuilder extends PageTransitionsBuilder {
  const OneDrivePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// App-wide light/dark switch used by the app bar theme buttons.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);

  bool isDark(Brightness platformBrightness) => switch (value) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => platformBrightness == Brightness.dark,
  };

  void toggle(Brightness platformBrightness) {
    value = isDark(platformBrightness) ? ThemeMode.light : ThemeMode.dark;
  }
}
