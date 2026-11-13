import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// The fonts of a printed page: the app's (Plus Jakarta Sans), with IBM Plex Sans Arabic for Arabic text.
class PdfFonts {
  const PdfFonts({required this.regular, required this.bold, this.fallback = const []});

  final pw.Font regular;
  final pw.Font bold;
  final List<pw.Font> fallback;
}

/// Prints a PDF made on the device: the browser's print window on a computer, the system one on a phone
/// (where it can also be saved or shared).
abstract interface class DocumentPrinter {
  /// [arabic]: the Arabic font first.
  Future<PdfFonts> fonts({required bool arabic});

  Future<void> printPdf(String name, Future<Uint8List> Function(PdfPageFormat format) build);

  /// Saves the PDF: a download in the browser, the share sheet on a phone (WhatsApp, e-mail, print).
  Future<void> share(String fileName, Uint8List bytes);
}

class PrintingDocumentPrinter implements DocumentPrinter {
  /// The fonts come with the app (assets/google_fonts): nothing is downloaded to print.
  static Future<pw.Font> _font(String file) async => pw.Font.ttf(await rootBundle.load('assets/google_fonts/$file'));

  @override
  Future<PdfFonts> fonts({required bool arabic}) async {
    final arabicRegular = await _font('IBMPlexSansArabic-Regular.ttf');
    final arabicBold = await _font('IBMPlexSansArabic-Bold.ttf');
    final regular = await _font('PlusJakartaSans-Regular.ttf');
    if (arabic) return PdfFonts(regular: arabicRegular, bold: arabicBold, fallback: [regular]);
    return PdfFonts(regular: regular, bold: await _font('PlusJakartaSans-Bold.ttf'), fallback: [arabicRegular]);
  }

  @override
  Future<void> printPdf(String name, Future<Uint8List> Function(PdfPageFormat format) build) => Printing.layoutPdf(name: name, onLayout: build);

  @override
  Future<void> share(String fileName, Uint8List bytes) => Printing.sharePdf(bytes: bytes, filename: fileName);
}
