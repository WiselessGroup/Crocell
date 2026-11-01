import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

/// The two languages Crocell speaks. Picked once, from the system: no
/// setting, people already told their system which language they read.
enum Lang { ru, en }

/// System languages whose people read Russian more easily than English.
const _russian = {'ru', 'be', 'kk'};

Lang lang = _detect();

Lang _detect() {
  // Widget tests look for the Russian texts.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return Lang.ru;
  return langFor(PlatformDispatcher.instance.locale);
}

Lang langFor(Locale locale) => _russian.contains(locale.languageCode) ? Lang.ru : Lang.en;

/// The text in the app's language. Russian first, as the app was written.
String tr(String ru, String en) => lang == Lang.ru ? ru : en;

/// For MaterialApp, so system widgets (tooltips, text menus) match.
Locale get appLocale => lang == Lang.ru ? const Locale('ru') : const Locale('en');
