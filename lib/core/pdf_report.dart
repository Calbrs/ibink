import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/revenue_model.dart';
import '../core/session.dart';
import '../widgets/notification_modals.dart';

class PdfReport {
  static Future<void> generateAndPrintRevenueReport(RevenueSummary summary, String rangeLabel) async {
    final pdf = pw.Document();

    final shopName = Session.instance.shopName ?? 'Duka Langu';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(shopName, rangeLabel),
            pw.SizedBox(height: 20),
            _buildSummaryBox(summary),
            pw.SizedBox(height: 20),
            pw.Text(
              'Bidhaa Zinazouza Sana',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildTopProductsTable(summary.topProducts),
            pw.SizedBox(height: 20),
            pw.Text(
              'Mwenendo wa Mapato',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildTrendTable(summary.trendEntries),
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted && !await Permission.manageExternalStorage.request().isGranted) {
           // Fallback if no permission
           _fallbackShare(bytes, rangeLabel);
           return;
        }

        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/Ripoti_ya_Mapato_$rangeLabel.pdf');
          await file.writeAsBytes(bytes);
          return; // Tumemaliza, success!
        }
      }

      // Kwa iOS au kama Android inashindwa kupata Download dir
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Ripoti_ya_Mapato_$rangeLabel.pdf');
      await file.writeAsBytes(bytes);

      // On iOS / fallback, share is usually better to allow user to save to Files
      if (Platform.isIOS) {
         _fallbackShare(bytes, rangeLabel);
      }
    } catch (e) {
      _fallbackShare(bytes, rangeLabel);
    }
  }

  static Future<void> _fallbackShare(List<int> bytes, String rangeLabel) async {
    try {
      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/Ripoti_ya_Mapato_$rangeLabel.pdf');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Ripoti ya Mapato: $rangeLabel',
        ),
      );
    } catch (_) {}
  }

  static pw.Widget _buildHeader(String shopName, String rangeLabel) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              shopName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Ripoti ya Mapato: $rangeLabel',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Tarehe: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'IBINK.ME',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryBox(RevenueSummary summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Jumla ya Mapato', 'TZS ${_fmt(summary.totalRevenue)}'),
          _summaryItem('Idadi ya Mauzo', '${summary.totalSalesCount}'),
          _summaryItem('Bidhaa Zilizouzwa', '${summary.totalQuantitySold}'),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildTopProductsTable(List<TopProductRevenue> products) {
    if (products.isEmpty) {
      return pw.Text('Hakuna bidhaa zilizouzwa katika kipindi hiki.', style: const pw.TextStyle(color: PdfColors.grey600));
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Na.', 'Jina la Bidhaa', 'Zilizouzwa', 'Mapato (TZS)'],
      data: List.generate(products.length, (index) {
        final p = products[index];
        return [
          '${index + 1}',
          p.productName,
          '${p.unitsSold}',
          _fmt(p.revenue),
        ];
      }),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _buildTrendTable(List<TrendEntry> entries) {
    if (entries.isEmpty) {
      return pw.Text('Hakuna data ya mwenendo.', style: const pw.TextStyle(color: PdfColors.grey600));
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Kipindi', 'Mapato (TZS)', 'Bidhaa Iliyouza Zaidi'],
      data: entries.map((e) {
        final top = e.topProduct != null ? '${e.topProduct!.productName} (${e.topProduct!.unitsSold})' : '-';
        return [
          e.label,
          _fmt(e.amount),
          top,
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
