import '/components/drawer_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/backend.dart';
import 'library_home_widget.dart' show LibraryHomeWidget;
import 'package:flutter/material.dart';

class LibraryHomeModel extends FlutterFlowModel<LibraryHomeWidget> {
  // Model for drawerComponent component.
  late DrawerComponentModel drawerComponentModel;

  // Streams cacheados para no recrear la consulta en cada build.
  // Se regeneran solo cuando cambia el idioma.
  Stream<List<TalesRecord>>? _talesStream;
  String? _talesStreamLang;
  Stream<List<CategoriesRecord>>? _categoriesStream;

  // Consultamos Firestore directamente en vez de usar queryTalesRecord /
  // queryCategoriesRecord: esos helpers tragan el error con handleError y el
  // StreamBuilder nunca veria hasError (spinner eterno en vez de reintentar).
  Stream<List<TalesRecord>> talesStreamFor(String lang) {
    if (_talesStream == null || _talesStreamLang != lang) {
      _talesStreamLang = lang;
      _talesStream = TalesRecord.collection
          .where('lang', isEqualTo: lang)
          .orderBy('tale_id', descending: true)
          .snapshots()
          .map((s) => s.docs.map(TalesRecord.fromSnapshot).toList());
    }
    return _talesStream!;
  }

  Stream<List<CategoriesRecord>> categoriesStream() {
    _categoriesStream ??= CategoriesRecord.collection
        .orderBy('sort_order')
        .snapshots()
        .map((s) => s.docs.map(CategoriesRecord.fromSnapshot).toList());
    return _categoriesStream!;
  }

  /// Fuerza la recreacion de streams (boton reintentar).
  void resetStreams() {
    _talesStream = null;
    _categoriesStream = null;
  }

  @override
  void initState(BuildContext context) {
    drawerComponentModel = createModel(context, () => DrawerComponentModel());
  }

  @override
  void dispose() {
    drawerComponentModel.dispose();
  }
}
