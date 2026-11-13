import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget drawn off screen into a PNG, at its own size: a formula for a printed sheet (the PDF keeps its text
/// as text; only formulas are pictures). [pixelRatio] 5 gives about 360 dots per inch at the printed size.
/// Returns the PNG and the widget's size in logical pixels (which the PDF takes as points).
Future<(Uint8List, Size)> widgetToPng(Widget widget, {double pixelRatio = 5, Size room = const Size(1600, 400)}) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    configuration: ViewConfiguration(logicalConstraints: BoxConstraints.tight(room), devicePixelRatio: 1),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final build = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(textDirection: TextDirection.ltr, child: widget),
    ),
  ).attachToRenderTree(build);
  build
    ..buildScope(root)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final size = boundary.size;
  image.dispose();
  return (bytes!.buffer.asUint8List(), size);
}
