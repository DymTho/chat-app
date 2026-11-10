import 'package:material_ui/material_ui.dart';

/// The four colour schemes the user can pick in Settings.
enum PaletteId { sunset, sky, mint, neon }

/// A palette describes the brand colours of a theme. Every palette has a light
/// and a dark variant, produced by [AppPalette.resolve].
class PaletteSpec {
  const PaletteSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.lightBackground,
    required this.darkBackground,
    required this.lightSurface,
    required this.darkSurface,
    required this.lightHeader,
    required this.darkHeader,
    required this.gradientLight,
    required this.gradientDark,
    this.glass = false,
  });

  final PaletteId id;
  final String name;
  final String description;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color lightBackground;
  final Color darkBackground;
  final Color lightSurface;
  final Color darkSurface;
  final Color lightHeader;
  final Color darkHeader;
  final List<Color> gradientLight;
  final List<Color> gradientDark;

  /// Glassy, translucent cards (the "Sky" look).
  final bool glass;

  static const sunset = PaletteSpec(
    id: PaletteId.sunset,
    name: 'Sunset',
    description: 'Warm coral orange',
    primary: Color(0xFFF2784B),
    secondary: Color(0xFFFFA06B),
    accent: Color(0xFF2B2B2E),
    lightBackground: Color(0xFFF7F5F3),
    darkBackground: Color(0xFF151517),
    lightSurface: Colors.white,
    darkSurface: Color(0xFF222226),
    lightHeader: Color(0xFF2B2B2E),
    darkHeader: Color(0xFF0E0E10),
    gradientLight: [Color(0xFFFF9A6C), Color(0xFFF2784B)],
    gradientDark: [Color(0xFF3A2219), Color(0xFF151517)],
  );

  static const sky = PaletteSpec(
    id: PaletteId.sky,
    name: 'Sky',
    description: 'Airy glass blue',
    primary: Color(0xFF3B8CF0),
    secondary: Color(0xFF7DB8FF),
    accent: Color(0xFF1B4F9C),
    lightBackground: Color(0xFFEAF3FF),
    darkBackground: Color(0xFF0B1424),
    lightSurface: Color(0xFFFFFFFF),
    darkSurface: Color(0xFF16243A),
    lightHeader: Color(0xFF3B8CF0),
    darkHeader: Color(0xFF0F1D33),
    gradientLight: [Color(0xFFBFDBFF), Color(0xFF4F9BF5)],
    gradientDark: [Color(0xFF16305A), Color(0xFF0B1424)],
    glass: true,
  );

  static const mint = PaletteSpec(
    id: PaletteId.mint,
    name: 'Mint',
    description: 'Fresh calm green',
    primary: Color(0xFF1FAA7A),
    secondary: Color(0xFF6FD6A8),
    accent: Color(0xFF0E5C44),
    lightBackground: Color(0xFFF1F8F4),
    darkBackground: Color(0xFF0D1613),
    lightSurface: Colors.white,
    darkSurface: Color(0xFF17241F),
    lightHeader: Color(0xFF16473A),
    darkHeader: Color(0xFF0A110E),
    gradientLight: [Color(0xFF8BE3BC), Color(0xFF1FAA7A)],
    gradientDark: [Color(0xFF123B2D), Color(0xFF0D1613)],
  );

  static const neon = PaletteSpec(
    id: PaletteId.neon,
    name: 'Neon',
    description: 'Violet × acid green',
    primary: Color(0xFF9B5CFF),
    secondary: Color(0xFF39FFA0),
    accent: Color(0xFF39FFA0),
    lightBackground: Color(0xFFF4F0FF),
    darkBackground: Color(0xFF0B0814),
    lightSurface: Colors.white,
    darkSurface: Color(0xFF17122A),
    lightHeader: Color(0xFF1A1033),
    darkHeader: Color(0xFF07050E),
    gradientLight: [Color(0xFFC6A6FF), Color(0xFF7B3DF0)],
    gradientDark: [Color(0xFF2A1752), Color(0xFF0B0814)],
  );

  static const all = [sunset, sky, mint, neon];

  static PaletteSpec byId(PaletteId id) => all.firstWhere((p) => p.id == id);
}

/// Theme extension with the extra colours that [ColorScheme] has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.spec,
    required this.isDark,
    required this.header,
    required this.onHeader,
    required this.bubbleMine,
    required this.onBubbleMine,
    required this.bubbleOther,
    required this.onBubbleOther,
    required this.gradient,
    required this.muted,
    required this.card,
    required this.navBar,
    required this.navSelected,
    required this.navBadge,
    required this.headerAccent,
    required this.online,
    required this.shadow,
  });

  factory AppPalette.resolve(PaletteSpec spec, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final card = dark ? spec.darkSurface : spec.lightSurface;
    final navBar = dark ? const Color(0xFF0B0B0D) : spec.lightHeader;
    // When the bar itself is the brand colour (Sky light), a primary-coloured
    // selected icon would vanish — use white and a red badge instead.
    final navBlends = _distance(navBar, spec.primary) < 0.15;
    return AppPalette(
      spec: spec,
      isDark: dark,
      header: dark ? spec.darkHeader : spec.lightHeader,
      onHeader: Colors.white,
      bubbleMine: spec.primary,
      onBubbleMine: spec.id == PaletteId.neon ? Colors.white : Colors.white,
      bubbleOther: dark
          ? Color.lerp(spec.darkSurface, Colors.white, 0.06)!
          : const Color(0xFFF0EFF2),
      onBubbleOther: dark ? const Color(0xFFECECF1) : const Color(0xFF2B2B2E),
      gradient: dark ? spec.gradientDark : spec.gradientLight,
      muted: dark ? const Color(0xFF8E8E99) : const Color(0xFF9A9AA3),
      card: spec.glass ? card.withValues(alpha: dark ? 0.72 : 0.78) : card,
      navBar: navBar,
      navSelected: navBlends ? Colors.white : spec.primary,
      navBadge: navBlends ? const Color(0xFFE5484D) : spec.primary,
      headerAccent: navBlends && !dark ? Colors.white : spec.secondary,
      online: spec.id == PaletteId.neon ? spec.secondary : const Color(0xFF34C759),
      shadow: dark
          ? Colors.black.withValues(alpha: 0.45)
          : spec.primary.withValues(alpha: 0.12),
    );
  }

  final PaletteSpec spec;
  final bool isDark;
  final Color header;
  final Color onHeader;
  final Color bubbleMine;
  final Color onBubbleMine;
  final Color bubbleOther;
  final Color onBubbleOther;
  final List<Color> gradient;
  final Color muted;
  final Color card;
  final Color navBar;

  /// Icon/label colour of the selected bottom-bar item.
  final Color navSelected;

  /// Unread badge colour on the bottom bar.
  final Color navBadge;

  /// Highlight text (online / typing) on the chat header.
  final Color headerAccent;
  final Color online;
  final Color shadow;

  List<BoxShadow> get softShadow => [
        BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 10)),
      ];

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      spec: t < 0.5 ? spec : other.spec,
      isDark: t < 0.5 ? isDark : other.isDark,
      header: Color.lerp(header, other.header, t)!,
      onHeader: Color.lerp(onHeader, other.onHeader, t)!,
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      onBubbleMine: Color.lerp(onBubbleMine, other.onBubbleMine, t)!,
      bubbleOther: Color.lerp(bubbleOther, other.bubbleOther, t)!,
      onBubbleOther: Color.lerp(onBubbleOther, other.onBubbleOther, t)!,
      gradient: [
        for (var i = 0; i < gradient.length; i++)
          Color.lerp(gradient[i], other.gradient[i], t)!,
      ],
      muted: Color.lerp(muted, other.muted, t)!,
      card: Color.lerp(card, other.card, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navSelected: Color.lerp(navSelected, other.navSelected, t)!,
      navBadge: Color.lerp(navBadge, other.navBadge, t)!,
      headerAccent: Color.lerp(headerAccent, other.headerAccent, t)!,
      online: Color.lerp(online, other.online, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Squared RGB distance: 0 for identical colours, 3 for black vs white.
double _distance(Color a, Color b) {
  final dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
  return dr * dr + dg * dg + db * db;
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
