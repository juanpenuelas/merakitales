import '/components/tale_detail_mobile_component_widget.dart';
import '/components/tale_detail_tablet_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'tail_detail_widget.dart' show TailDetailWidget;
import 'package:flutter/material.dart';

class TailDetailModel extends FlutterFlowModel<TailDetailWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for taleDetailMobileComponent component.
  late TaleDetailMobileComponentModel taleDetailMobileComponentModel;
  // Model for taleDetailTabletComponent component.
  late TaleDetailTabletComponentModel taleDetailTabletComponentModel;

  @override
  void initState(BuildContext context) {
    taleDetailMobileComponentModel =
        createModel(context, () => TaleDetailMobileComponentModel());
    taleDetailTabletComponentModel =
        createModel(context, () => TaleDetailTabletComponentModel());
  }

  @override
  void dispose() {
    taleDetailMobileComponentModel.dispose();
    taleDetailTabletComponentModel.dispose();
  }
}
