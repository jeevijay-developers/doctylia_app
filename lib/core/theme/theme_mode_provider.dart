import 'dart:async';

import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _preferenceKey = 'theme_mode';

  @override
  ThemeMode build() {
    unawaited(_restore());
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final value = await ref
        .read(preferencesStoreProvider)
        .getString(_preferenceKey);
    if (!ref.mounted) return;
    state = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    await ref
        .read(preferencesStoreProvider)
        .setString(_preferenceKey, enabled ? 'dark' : 'light');
  }
}
