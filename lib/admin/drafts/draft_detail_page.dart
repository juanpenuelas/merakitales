import 'package:flutter/material.dart';
class DraftDetailPage extends StatelessWidget {
  const DraftDetailPage({super.key, required this.draftId});
  final String draftId;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('detail $draftId')));
}
