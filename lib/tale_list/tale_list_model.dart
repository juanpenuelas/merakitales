import '/components/drawer_component_widget.dart';
import '/components/tale_list_large_component_widget.dart';
import '/components/tale_list_mobile_component_widget.dart';
import '/components/tale_list_tablet_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'tale_list_widget.dart' show TaleListWidget;
import 'package:flutter/material.dart';

class TaleListModel extends FlutterFlowModel<TaleListWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for drawerComponent component.
  late DrawerComponentModel drawerComponentModel;
  // Model for taleListMobileComponent component.
  late TaleListMobileComponentModel taleListMobileComponentModel;
  // Model for taleListTabletComponent component.
  late TaleListTabletComponentModel taleListTabletComponentModel;
  // Model for taleListLargeComponent component.
  late TaleListLargeComponentModel taleListLargeComponentModel;

  @override
  void initState(BuildContext context) {
    drawerComponentModel = createModel(context, () => DrawerComponentModel());
    taleListMobileComponentModel =
        createModel(context, () => TaleListMobileComponentModel());
    taleListTabletComponentModel =
        createModel(context, () => TaleListTabletComponentModel());
    taleListLargeComponentModel =
        createModel(context, () => TaleListLargeComponentModel());
  }

  @override
  void dispose() {
    drawerComponentModel.dispose();
    taleListMobileComponentModel.dispose();
    taleListTabletComponentModel.dispose();
    taleListLargeComponentModel.dispose();
  }
}
