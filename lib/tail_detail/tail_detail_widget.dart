import '/backend/backend.dart';
import '/components/tale_detail_mobile_component_widget.dart';
import '/components/tale_detail_tablet_component_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'tail_detail_model.dart';
export 'tail_detail_model.dart';

class TailDetailWidget extends StatefulWidget {
  const TailDetailWidget({
    super.key,
    required this.taleParameter,
  });

  final TalesRecord? taleParameter;

  static String routeName = 'tailDetail';
  static String routePath = '/tailDetail';

  @override
  State<TailDetailWidget> createState() => _TailDetailWidgetState();
}

class _TailDetailWidgetState extends State<TailDetailWidget> {
  late TailDetailModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TailDetailModel());
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
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
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
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                    child: wrapWithModel(
                      model: _model.taleDetailMobileComponentModel,
                      updateCallback: () => safeSetState(() {}),
                      child: TaleDetailMobileComponentWidget(
                        taleDetailParameter: widget.taleParameter!,
                      ),
                    ),
                  ),
                ),
              if (responsiveVisibility(
                context: context,
                phone: false,
              ))
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                    child: wrapWithModel(
                      model: _model.taleDetailTabletComponentModel,
                      updateCallback: () => safeSetState(() {}),
                      child: TaleDetailTabletComponentWidget(
                        taleDetailParameter: widget.taleParameter!,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
