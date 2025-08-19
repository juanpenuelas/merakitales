import '/components/drawer_component_widget.dart';
import '/components/tale_list_large_component_widget.dart';
import '/components/tale_list_mobile_component_widget.dart';
import '/components/tale_list_tablet_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'tale_list_model.dart';
export 'tale_list_model.dart';

class TaleListWidget extends StatefulWidget {
  const TaleListWidget({super.key});

  static String routeName = 'taleList';
  static String routePath = '/taleList';

  @override
  State<TaleListWidget> createState() => _TaleListWidgetState();
}

class _TaleListWidgetState extends State<TaleListWidget> {
  late TaleListModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TaleListModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF1F4F8),
        drawer: Drawer(
          elevation: 16.0,
          child: wrapWithModel(
            model: _model.drawerComponentModel,
            updateCallback: () => safeSetState(() {}),
            child: DrawerComponentWidget(),
          ),
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (responsiveVisibility(
              context: context,
              tablet: false,
              tabletLandscape: false,
              desktop: false,
            ))
              Expanded(
                child: Container(
                  decoration: BoxDecoration(),
                  child: wrapWithModel(
                    model: _model.taleListMobileComponentModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TaleListMobileComponentWidget(),
                  ),
                ),
              ),
            if (responsiveVisibility(
              context: context,
              phone: false,
              tabletLandscape: false,
              desktop: false,
            ))
              Expanded(
                child: Container(
                  decoration: BoxDecoration(),
                  child: wrapWithModel(
                    model: _model.taleListTabletComponentModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TaleListTabletComponentWidget(),
                  ),
                ),
              ),
            if (responsiveVisibility(
              context: context,
              phone: false,
              tablet: false,
            ))
              Expanded(
                child: Container(
                  decoration: BoxDecoration(),
                  child: wrapWithModel(
                    model: _model.taleListLargeComponentModel,
                    updateCallback: () => safeSetState(() {}),
                    child: TaleListLargeComponentWidget(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
