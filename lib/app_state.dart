import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _TalesReadSinceLastIntersticialAdd =
          prefs.getInt('ff_TalesReadSinceLastIntersticialAdd') ??
              _TalesReadSinceLastIntersticialAdd;
    });
    _safeInit(() {
      _updateLanguage = prefs.getInt('ff_updateLanguage') ?? _updateLanguage;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  int _TalesReadSinceLastIntersticialAdd = 0;
  int get TalesReadSinceLastIntersticialAdd =>
      _TalesReadSinceLastIntersticialAdd;
  set TalesReadSinceLastIntersticialAdd(int value) {
    _TalesReadSinceLastIntersticialAdd = value;
    prefs.setInt('ff_TalesReadSinceLastIntersticialAdd', value);
  }

  int _updateLanguage = 0;
  int get updateLanguage => _updateLanguage;
  set updateLanguage(int value) {
    _updateLanguage = value;
    prefs.setInt('ff_updateLanguage', value);
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
