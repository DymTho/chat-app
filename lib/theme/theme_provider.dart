import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

class ThemeSettings {
  const ThemeSettings({required this.palette, required this.mode});

  final PaletteId palette;
  final ThemeMode mode;

  ThemeSettings copyWith({PaletteId? palette, ThemeMode? mode}) =>
      ThemeSettings(palette: palette ?? this.palette, mode: mode ?? this.mode);
}

class ThemeController extends Notifier<ThemeSettings> {
  static const _paletteKey = 'theme.palette';
  static const _modeKey = 'theme.mode';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final paletteName = prefs.getString(_paletteKey);
    final modeName = prefs.getString(_modeKey);
    return ThemeSettings(
      palette: PaletteId.values.firstWhere(
        (p) => p.name == paletteName,
        orElse: () => PaletteId.sunset,
      ),
      mode: ThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  void setPalette(PaletteId palette) {
    state = state.copyWith(palette: palette);
    ref.read(sharedPrefsProvider).setString(_paletteKey, palette.name);
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    ref.read(sharedPrefsProvider).setString(_modeKey, mode.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

/// Whether the in‑app (local) message notifications are enabled.
class NotificationsEnabled extends Notifier<bool> {
  static const _key = 'notifications.enabled';

  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(_key) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPrefsProvider).setBool(_key, value);
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabled, bool>(NotificationsEnabled.new);
