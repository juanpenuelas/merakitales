import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/components/notification_offer_dialog.dart';
import '/flutter_flow/admob_util.dart' as admob;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/notification_prompt_policy.dart';
import '/services/notification_service.dart';

/// Abre el detalle de un cuento contando la apertura para el intersticial
/// (uno cada 5 aperturas), logica movida sin cambios desde la antigua lista.
Future<void> openTale(BuildContext context, TalesRecord tale) async {
  FFAppState().TalesReadSinceLastIntersticialAdd =
      FFAppState().TalesReadSinceLastIntersticialAdd + 1;
  if (FFAppState().TalesReadSinceLastIntersticialAdd >= 5) {
    final success = await admob.showInterstitialAd();

    admob.loadInterstitialAd(
      "ca-app-pub-6049242703708474/2634885084",
      "ca-app-pub-6049242703708474/1026289941",
      false,
    );

    if (success) {
      FFAppState().TalesReadSinceLastIntersticialAdd = 0;
    }
  }

  if (!context.mounted) return;
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
