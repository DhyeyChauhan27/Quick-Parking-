import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render QuickParking Material logo assets', (tester) async {
    await tester.runAsync(_loadMaterialIconsFont);
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _renderAsset(
      tester,
      path: 'assets/branding/quickparking_icon.png',
      child: Center(
        child: Container(
          width: 964,
          height: 964,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(220),
          ),
          child: const Icon(
            Icons.local_parking_rounded,
            size: 560,
            color: Color(0xFF0F766E),
          ),
        ),
      ),
    );

    await _renderAsset(
      tester,
      path: 'assets/branding/quickparking_mark.png',
      child: const Center(
        child: Icon(
          Icons.local_parking_rounded,
          size: 560,
          color: Color(0xFF0F766E),
        ),
      ),
    );
  });
}

Future<void> _loadMaterialIconsFont() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('Run this renderer with flutter test.');
  }
  final fontFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  final fontBytes = await fontFile.readAsBytes();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(fontBytes)));
  await loader.load();
}

Future<void> _renderAsset(
  WidgetTester tester, {
  required String path,
  required Widget child,
}) async {
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: boundaryKey,
        child: ColoredBox(
          color: Colors.transparent,
          child: SizedBox(width: 1024, height: 1024, child: child),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final rendered = await boundary.toImage();
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
