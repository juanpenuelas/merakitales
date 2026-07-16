import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/admob_util.dart' as admob;
import '/flutter_flow/flutter_flow_native_ad.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'tale_list_mobile_component_model.dart';
export 'tale_list_mobile_component_model.dart';

class TaleListMobileComponentWidget extends StatefulWidget {
  const TaleListMobileComponentWidget({super.key});

  @override
  State<TaleListMobileComponentWidget> createState() =>
      _TaleListMobileComponentWidgetState();
}

class _TaleListMobileComponentWidgetState
    extends State<TaleListMobileComponentWidget> {
  late TaleListMobileComponentModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TaleListMobileComponentModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Color(0xFFF1F4F8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 140.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Image.network(
                        'https://images.unsplash.com/photo-1626684496076-07e23c6361ff?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxzZWFyY2h8NHx8bW91bnRhaW4lMjBob3VzZXxlbnwwfHwwfHw%3D&auto=format&fit=crop&w=900&q=60',
                      ).image,
                    ),
                  ),
                  child: Container(
                    width: 100.0,
                    decoration: BoxDecoration(
                      color: Color(0x9A1D2428),
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: Image.asset(
                          'assets/images/meraki_tales_image01.png',
                        ).image,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0x3E000000),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 30.0, 0.0, 0.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                FlutterFlowIconButton(
                                  borderRadius: 20.0,
                                  borderWidth: 1.0,
                                  buttonSize: 60.0,
                                  icon: Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 30.0,
                                  ),
                                  onPressed: () async {
                                    Scaffold.of(context).openDrawer();
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                12.0, 30.0, 12.0, 12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 8.0),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      'li3thkua' /* Meraki Tales */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .displaySmall
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .displaySmall
                                                    .fontStyle,
                                          ),
                                          color: Colors.white,
                                          fontSize: 36.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .displaySmall
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                                Text(
                                  FFLocalizations.of(context).getText(
                                    'ks0xaoap' /* Historias para soñar y aprende... */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                        color: Color(0xBEFFFFFF),
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                FlutterFlowDropDown<String>(
                  controller: _model.dropDownValueController ??=
                      FormFieldController<String>(
                    _model.dropDownValue ??=
                        FFLocalizations.of(context).languageCode,
                  ),
                  options: List<String>.from(['es', 'en']),
                  optionLabels: [
                    FFLocalizations.of(context).getText(
                      'r8ll667x' /* Español */,
                    ),
                    FFLocalizations.of(context).getText(
                      'mtvpy5vs' /* English */,
                    )
                  ],
                  onChanged: (val) async {
                    safeSetState(() => _model.dropDownValue = val);
                    setAppLanguage(context, _model.dropDownValue!);
                    FFAppState().updateLanguage =
                        FFAppState().updateLanguage + 1;
                    FFAppState().update(() {});
                  },
                  width: 300.0,
                  height: 50.0,
                  textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.readexPro(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: Color(0xFF666666),
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                  hintText: FFLocalizations.of(context).getText(
                    'rrt2256e' /* Porfavor selecciona un idioma */,
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 24.0,
                  ),
                  fillColor: Color(0xFFF1F4F8),
                  elevation: 2.0,
                  borderColor: Colors.transparent,
                  borderWidth: 2.0,
                  borderRadius: 8.0,
                  margin: EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 4.0),
                  hidesUnderline: true,
                  isOverButton: true,
                  isSearchable: false,
                  isMultiSelect: false,
                ),
                StreamBuilder<List<CategoriesRecord>>(
                  stream: queryCategoriesRecord(
                    queryBuilder: (c) => c.orderBy('sort_order'),
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final categories = snapshot.data!;
                    if (categories.isEmpty) return const SizedBox.shrink();
                    
                    return SizedBox(
                      height: 50.0,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        itemBuilder: (context, index) {
                          final isAll = index == 0;
                          final category = isAll ? null : categories[index - 1];
                          final isSelected = isAll 
                              ? _model.selectedCategorySlug == null 
                              : _model.selectedCategorySlug == category?.slug;
                              
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _model.selectedCategorySlug = isAll ? null : category?.slug;
                                  _model.listViewPagingController?.refresh();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? FlutterFlowTheme.of(context).primary 
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected 
                                        ? FlutterFlowTheme.of(context).primary 
                                        : const Color(0xFFE0E3E7),
                                  ),
                                ),
                                child: Text(
                                  isAll 
                                      ? 'Todos' 
                                      : '${category!.emoji} ${FFLocalizations.of(context).languageCode == 'en' ? category.nameEn : category.nameEs}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF14181B),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                Expanded(
                  child: PagedListView<DocumentSnapshot<Object?>?, TalesRecord>(
                    pagingController: _model.setListViewController(
                      (_model.selectedCategorySlug == null)
                        ? TalesRecord.collection
                            .where(
                              'lang',
                              isEqualTo:
                                  '${FFLocalizations.of(context).languageCode}',
                            )
                            .orderBy('tale_id', descending: true)
                        : TalesRecord.collection
                            .where(
                              'lang',
                              isEqualTo:
                                  '${FFLocalizations.of(context).languageCode}',
                            )
                            .where(
                              'category_slug',
                              isEqualTo: _model.selectedCategorySlug,
                            )
                            .orderBy('tale_id', descending: true),
                    ),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    reverse: false,
                    scrollDirection: Axis.vertical,
                    builderDelegate: PagedChildBuilderDelegate<TalesRecord>(
                      // Customize what your widget looks like when it's loading the first page.
                      firstPageProgressIndicatorBuilder: (_) => Center(
                        child: SizedBox(
                          width: 50.0,
                          height: 50.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                      ),
                      // Customize what your widget looks like when it's loading another page.
                      newPageProgressIndicatorBuilder: (_) => Center(
                        child: SizedBox(
                          width: 50.0,
                          height: 50.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                      ),

                      itemBuilder: (context, _, listViewIndex) {
                        final listViewTalesRecord = _model
                            .listViewPagingController!.itemList![listViewIndex];
                        final taleTile = Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 4.0, 16.0, 8.0),
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              FFAppState().TalesReadSinceLastIntersticialAdd =
                                  FFAppState()
                                          .TalesReadSinceLastIntersticialAdd +
                                      1;
                              if (FFAppState()
                                      .TalesReadSinceLastIntersticialAdd >=
                                  5) {
                                _model.interstitialAdSuccess =
                                    await admob.showInterstitialAd();

                                if (_model.interstitialAdSuccess == true) {
                                  admob.loadInterstitialAd(
                                    "ca-app-pub-6049242703708474/2634885084",
                                    "ca-app-pub-6049242703708474/1026289941",
                                    false,
                                  );

                                  FFAppState()
                                      .TalesReadSinceLastIntersticialAdd = 0;
                                } else {
                                  admob.loadInterstitialAd(
                                    "ca-app-pub-6049242703708474/2634885084",
                                    "ca-app-pub-6049242703708474/1026289941",
                                    false,
                                  );
                                }
                              }

                              context.pushNamed(
                                TailDetailWidget.routeName,
                                queryParameters: {
                                  'taleParameter': serializeParam(
                                    listViewTalesRecord,
                                    ParamType.Document,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  'taleParameter': listViewTalesRecord,
                                },
                              );

                              safeSetState(() {});
                            },
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 3.0,
                                    color: Color(0x411D2429),
                                    offset: Offset(
                                      0.0,
                                      1.0,
                                    ),
                                  )
                                ],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 1.0, 1.0, 1.0),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6.0),
                                            child: Image.network(
                                              listViewTalesRecord.imageUrl640px,
                                              width: double.infinity,
                                              height: 200.0,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (listViewTalesRecord.isPremiumTale)
                                            Positioned(
                                              top: 8.0,
                                              right: 8.0,
                                              child: Container(
                                                padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(context).primary,
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                                child: Text(
                                                  '⭐ PREMIUM',
                                                  style: FlutterFlowTheme.of(context).labelSmall.override(
                                                    font: GoogleFonts.plusJakartaSans(),
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (listViewTalesRecord.createdAt != null && DateTime.now().difference(listViewTalesRecord.createdAt!).inDays <= 7)
                                            Positioned(
                                              top: 8.0,
                                              left: 8.0,
                                              child: Container(
                                                padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                                child: Text(
                                                  '✨ NUEVO',
                                                  style: FlutterFlowTheme.of(context).labelSmall.override(
                                                    font: GoogleFonts.plusJakartaSans(),
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 8.0, 0.0, 0.0),
                                      child: Text(
                                        listViewTalesRecord.name,
                                        style: FlutterFlowTheme.of(context)
                                            .headlineSmall
                                            .override(
                                              font: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineSmall
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF101213),
                                              fontSize: 22.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineSmall
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 4.0, 8.0, 8.0),
                                      child: Text(
                                        listViewTalesRecord.description,
                                        textAlign: TextAlign.start,
                                        style: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFF57636C),
                                              fontSize: 14.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        // Insert a Native Advanced ad after every two tales (at indices 1, 3, 5, ...)
                        // Android: no Native Advanced between tales. iOS (and others): keep behavior.
                        if (defaultTargetPlatform != TargetPlatform.android && listViewIndex % 2 == 1) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const NativeAdListTile(),
                              taleTile,
                            ],
                          );
                        } else {
                          return taleTile;
                        }
                      },
                    ),
                  ),
                ),

                // End of children for the inner Column
              ],
            ),
          ),
        ),
      ],
    );
  }
}
