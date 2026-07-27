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

  Stream<List<TalesRecord>> talesStreamFor(String lang) {
    if (_talesStream == null || _talesStreamLang != lang) {
      _talesStreamLang = lang;
      _talesStream = queryTalesRecord(
        queryBuilder: (q) => q
            .where('lang', isEqualTo: lang)
            .orderBy('tale_id', descending: true),
      );
    }
    return _talesStream!;
  }

  Stream<List<CategoriesRecord>> categoriesStream() {
    _categoriesStream ??= queryCategoriesRecord(
      queryBuilder: (q) => q.orderBy('sort_order'),
    );
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
