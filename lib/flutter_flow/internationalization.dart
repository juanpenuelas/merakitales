import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleStorageKey = '__locale_key__';

class FFLocalizations {
  FFLocalizations(this.locale);

  final Locale locale;

  static FFLocalizations of(BuildContext context) =>
      Localizations.of<FFLocalizations>(context, FFLocalizations)!;

  static List<String> languages() => ['es', 'en'];

  static late SharedPreferences _prefs;
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();
  static Future storeLocale(String locale) =>
      _prefs.setString(_kLocaleStorageKey, locale);
  static Locale? getStoredLocale() {
    final locale = _prefs.getString(_kLocaleStorageKey);
    return locale != null && locale.isNotEmpty ? createLocale(locale) : null;
  }

  String get languageCode => locale.toString();
  String? get languageShortCode =>
      _languagesWithShortCode.contains(locale.toString())
          ? '${locale.toString()}_short'
          : null;
  int get languageIndex => languages().contains(languageCode)
      ? languages().indexOf(languageCode)
      : 0;

  String getText(String key) =>
      (kTranslationsMap[key] ?? {})[locale.toString()] ?? '';

  String getVariableText({
    String? esText = '',
    String? enText = '',
  }) =>
      [esText, enText][languageIndex] ?? '';

  static const Set<String> _languagesWithShortCode = {
    'ar',
    'az',
    'ca',
    'cs',
    'da',
    'de',
    'dv',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'gr',
    'he',
    'hi',
    'hu',
    'it',
    'km',
    'ku',
    'mn',
    'ms',
    'no',
    'pt',
    'ro',
    'ru',
    'rw',
    'sv',
    'th',
    'uk',
    'vi',
  };
}

/// Used if the locale is not supported by GlobalMaterialLocalizations.
class FallbackMaterialLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

/// Used if the locale is not supported by GlobalCupertinoLocalizations.
class FallbackCupertinoLocalizationDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FFLocalizationsDelegate extends LocalizationsDelegate<FFLocalizations> {
  const FFLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<FFLocalizations> load(Locale locale) =>
      SynchronousFuture<FFLocalizations>(FFLocalizations(locale));

  @override
  bool shouldReload(FFLocalizationsDelegate old) => false;
}

Locale createLocale(String language) => language.contains('_')
    ? Locale.fromSubtags(
        languageCode: language.split('_').first,
        scriptCode: language.split('_').last,
      )
    : Locale(language);

bool _isSupportedLocale(Locale locale) {
  final language = locale.toString();
  return FFLocalizations.languages().contains(
    language.endsWith('_')
        ? language.substring(0, language.length - 1)
        : language,
  );
}

final kTranslationsMap = <Map<String, Map<String, String>>>[
  // HomePage
  {
    'vowm1smn': {
      'es': 'Page Title',
      'en': '',
    },
    '5a35uo54': {
      'es': 'Home',
      'en': '',
    },
  },
  // taleList
  {
    'sq3yx5x3': {
      'es': 'Home',
      'en': '',
    },
  },
  // tailDetail
  {
    'w0t0eldv': {
      'es': 'Home',
      'en': '',
    },
  },
  // drawerComponent
  {
    '3ico71tb': {
      'es': 'Abuela Meraki',
      'en': 'Grandma Meraki',
    },
    '6nifias4': {
      'es': 'Politica de privacidad',
      'en': 'Privacy policy',
    },
  },
  // taleListMobileComponent
  {
    'li3thkua': {
      'es': 'Abuela Meraki',
      'en': 'Grandma Meraki',
    },
    'ks0xaoap': {
      'es': 'Historias para soñar y aprender',
      'en': 'Tales to dream and learn.',
    },
    'rrt2256e': {
      'es': 'Porfavor selecciona un idioma',
      'en': 'Please select a language',
    },
    '8vkub8nv': {
      'es': 'Search for an item...',
      'en': '',
    },
    'r8ll667x': {
      'es': 'Español',
      'en': 'Español',
    },
    'mtvpy5vs': {
      'es': 'English',
      'en': 'English',
    },
  },
  // taleListLargeComponent
  {
    'r2qzxdbb': {
      'es': 'Abuela Meraki',
      'en': 'Grandma Meraki',
    },
    'knh5f1g0': {
      'es': 'Historias para soñar y aprender',
      'en': 'Tales to dream and learn.',
    },
    'b1tyqkmo': {
      'es': 'Porfavor selecciona un idioma',
      'en': 'Please select a language',
    },
    'jczceaod': {
      'es': 'Search for an item...',
      'en': '',
    },
    '5lb1up2i': {
      'es': 'Español',
      'en': 'Español',
    },
    'zycedmgc': {
      'es': 'English',
      'en': 'English',
    },
  },
  // taleListTabletComponent
  {
    't33crdqn': {
      'es': 'Abuela Meraki',
      'en': 'Grandma Meraki',
    },
    'octup6ez': {
      'es': 'Historias para soñar y aprender',
      'en': 'Tales to dream and learn.',
    },
    'jp542ya6': {
      'es': 'Porfavor selecciona un idioma',
      'en': 'Please select a language',
    },
    'j80covrf': {
      'es': 'Search for an item...',
      'en': '',
    },
    'uum24lli': {
      'es': 'Español',
      'en': 'Español',
    },
    'l3e703f9': {
      'es': 'English',
      'en': 'English',
    },
  },
  // Miscellaneous
  {
    'capyk148': {
      'es': '',
      'en': '',
    },
    'dgb8e4hs': {
      'es': '',
      'en': '',
    },
    '5vi0h4mr': {
      'es': '',
      'en': '',
    },
    'juxdnatc': {
      'es': '',
      'en': '',
    },
    'poovwijy': {
      'es': '',
      'en': '',
    },
    'b6z6770i': {
      'es': '',
      'en': '',
    },
    '07x129m0': {
      'es': '',
      'en': '',
    },
    '57l1b6ch': {
      'es': '',
      'en': '',
    },
    'psrb8dvm': {
      'es': '',
      'en': '',
    },
    'ht9f41sm': {
      'es': '',
      'en': '',
    },
    'izf7qaae': {
      'es': '',
      'en': '',
    },
    'zcxpyseq': {
      'es': '',
      'en': '',
    },
    'p1sgb3h7': {
      'es': '',
      'en': '',
    },
    'mj2vo47v': {
      'es': '',
      'en': '',
    },
    'lotl2im2': {
      'es': '',
      'en': '',
    },
    'e2fr0dg0': {
      'es': '',
      'en': '',
    },
    '86y2f6uu': {
      'es': '',
      'en': '',
    },
    'bgkfw4jx': {
      'es': '',
      'en': '',
    },
    'yifg8ge1': {
      'es': '',
      'en': '',
    },
    'x3lgml9o': {
      'es': '',
      'en': '',
    },
    '3q4blrg4': {
      'es': '',
      'en': '',
    },
    'rxuq8vek': {
      'es': '',
      'en': '',
    },
    'hztlc2qc': {
      'es': '',
      'en': '',
    },
    'ydi31uhh': {
      'es': '',
      'en': '',
    },
    'wwimhute': {
      'es': '',
      'en': '',
    },
    'jorn4m4a': {
      'es': '',
      'en': '',
    },
  },
].reduce((a, b) => a..addAll(b));
