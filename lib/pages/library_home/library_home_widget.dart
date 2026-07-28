import 'dart:async';

import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '/backend/backend.dart';
import '/components/drawer_component_widget.dart';
import '/components/premium_upsell_card.dart';
import '/components/shelf_row.dart';
import '/flutter_flow/admob_util.dart' as admob;
import '/flutter_flow/flutter_flow_ad_banner.dart';
import '/flutter_flow/flutter_flow_native_ad.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/category_page/category_page_widget.dart';
import '/services/shelf_builder.dart';
import '/services/subscription_service.dart';
import '/services/tale_opener.dart';
import 'library_home_model.dart';
export 'library_home_model.dart';

class LibraryHomeWidget extends StatefulWidget {
  const LibraryHomeWidget({super.key});

  static String routeName = 'libraryHome';
  static String routePath = '/libraryHome';

  @override
  State<LibraryHomeWidget> createState() => _LibraryHomeWidgetState();
}

class _LibraryHomeWidgetState extends State<LibraryHomeWidget> {
  late LibraryHomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LibraryHomeModel());

    // Precarga del intersticial, igual que hacia la lista antigua.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(
        () async {
          admob.loadInterstitialAd(
            "ca-app-pub-6049242703708474/2634885084",
            "ca-app-pub-6049242703708474/1026289941",
            false,
          );
        }(),
      );
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _shelfTitle(Shelf shelf, bool isSpanish) {
    switch (shelf.type) {
      case ShelfType.novedades:
        return isSpanish ? '✨ Novedades' : '✨ New arrivals';
      case ShelfType.gratis:
        return isSpanish ? '🎁 Cuentos gratis' : '🎁 Free tales';
      case ShelfType.categoria:
        final c = shelf.category!;
        final name = isSpanish ? c.nameEs : c.nameEn;
        return c.emoji.isEmpty ? name : '${c.emoji} $name';
    }
  }

  void _openShelf(Shelf shelf, bool isSpanish) {
    String title;
    String? emoji;
    switch (shelf.type) {
      case ShelfType.novedades:
        title = isSpanish ? 'Novedades' : 'New arrivals';
        emoji = '✨';
        break;
      case ShelfType.gratis:
        title = isSpanish ? 'Cuentos gratis' : 'Free tales';
        emoji = '🎁';
        break;
      case ShelfType.categoria:
        title = isSpanish ? shelf.category!.nameEs : shelf.category!.nameEn;
        emoji = shelf.category!.emoji.isEmpty ? null : shelf.category!.emoji;
        break;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPageWidget(
          title: title,
          emoji: emoji,
          tales: shelf.tales,
        ),
      ),
    );
  }

  Widget _loading() => Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      );

  Widget _error(bool isSpanish) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSpanish
                  ? 'No se pudieron cargar los cuentos'
                  : 'Could not load the tales',
              style: GoogleFonts.plusJakartaSans(fontSize: 14.0),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: () => setState(() => _model.resetStreams()),
              child: Text(isSpanish ? 'Reintentar' : 'Retry'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final lang = FFLocalizations.of(context).languageCode;
    final isPremiumUser = context.watch<PremiumProvider>().isPremium;
    final width = MediaQuery.sizeOf(context).width;
    final coverSize = width < 479
        ? 120.0
        : width < 767
            ? 140.0
            : 160.0;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF1F4F8),
      drawer: Drawer(
        elevation: 16.0,
        child: wrapWithModel(
          model: _model.drawerComponentModel,
          updateCallback: () => safeSetState(() {}),
          child: DrawerComponentWidget(),
        ),
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF2D5A3D),
              padding:
                  const EdgeInsetsDirectional.fromSTEB(4.0, 6.0, 16.0, 6.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu,
                        color: Colors.white, size: 28.0),
                    onPressed: () => scaffoldKey.currentState?.openDrawer(),
                    tooltip: isSpanish ? 'Menú' : 'Menu',
                  ),
                  Text(
                    'Meraki Tales',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CategoriesRecord>>(
                stream: _model.categoriesStream(),
                builder: (context, catSnap) {
                  return StreamBuilder<List<TalesRecord>>(
                    stream: _model.talesStreamFor(lang),
                    builder: (context, talesSnap) {
                      if (catSnap.hasError || talesSnap.hasError) {
                        return _error(isSpanish);
                      }
                      if (!catSnap.hasData || !talesSnap.hasData) {
                        return _loading();
                      }
                      final shelves = buildShelves(
                        tales: talesSnap.data!,
                        categories: catSnap.data!,
                        isPremiumUser: isPremiumUser,
                      );

                      final rows = <Widget>[];
                      var shelvesPintadas = 0;
                      for (final shelf in shelves) {
                        rows.add(ShelfRow(
                          title: _shelfTitle(shelf, isSpanish),
                          tales: shelf.tales,
                          isPremiumUser: isPremiumUser,
                          coverSize: coverSize,
                          onTaleTap: (tale) => openTale(context, tale),
                          onVerMas: () => _openShelf(shelf, isSpanish),
                        ));
                        shelvesPintadas++;
                        if (shelvesPintadas == 1 && !isPremiumUser) {
                          rows.add(const PremiumUpsellCard());
                        }
                        if (shelvesPintadas % 3 == 0 &&
                            defaultTargetPlatform != TargetPlatform.android) {
                          rows.add(const NativeAdListTile());
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => rows[index],
                      );
                    },
                  );
                },
              ),
            ),
            FlutterFlowAdBanner(
              width: MediaQuery.sizeOf(context).width * 1.0,
              height: 50.0,
              showsTestAd: kDebugMode,
              iOSAdUnitID: 'ca-app-pub-6049242703708474/6940127458',
              androidAdUnitID: 'ca-app-pub-6049242703708474/5874457795',
            ),
          ],
        ),
      ),
    );
  }
}
