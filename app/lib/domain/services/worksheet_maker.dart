import 'dart:typed_data';

import '../model/worksheet.dart';

/// Makes the PDF of a worksheet (A4 portrait), on the device.
abstract interface class WorksheetMaker {
  /// [arabic]: the teacher's language is Arabic (the Arabic font first, the sheet right to left).
  Future<Uint8List> pdf(Worksheet sheet, {required bool arabic});
}
