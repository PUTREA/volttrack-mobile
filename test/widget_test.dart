// Smoke test dasar VoltTrack Mobile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:volttrack_mobile/main.dart';

void main() {
  testWidgets('App boots and shows a loading gate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VoltTrackApp());

    // Saat boot, _Gate menampilkan indikator loading sebelum cek token.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
