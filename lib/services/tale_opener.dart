import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/components/notification_offer_dialog.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/notification_prompt_policy.dart';
import '/services/notification_service.dart';

/// Abre el detalle de un cuento y, al volver, aprovecha para ofrecer
/// notificaciones si la politica de reofertas lo permite.
Future<void> openTale(BuildContext context, TalesRecord tale) async {
  await context.pushNamed(
    TailDetailWidget.routeName,
    queryParameters: {
      'taleParameter': serializeParam(
        tale,
        ParamType.Document,
      ),
    }.withoutNulls,
    extra: <String, dynamic>{
      'taleParameter': tale,
    },
  );

  // Al volver del detalle (pop), oportunidad de ofrecer notificaciones.
  if (!context.mounted) return;
  final policy = NotificationPromptPolicy();
  await policy.recordTaleOpen();
  if (!await policy.shouldOfferNow()) return;

  await policy.recordOfferShown();
  if (!context.mounted) return;
  final wantsNotifications = await showDialog<bool>(
    context: context,
    builder: (_) => const NotificationOfferDialog(),
  );

  if (wantsNotifications == true) {
    final granted = await NotificationService().requestPermissionAndSubscribe();
    if (granted) {
      await policy.markDone();
    }
  }
}
