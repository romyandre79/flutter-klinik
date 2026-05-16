import 'dart:io';
import 'package:kreatif_klinik/core/constants/app_constants.dart';
import 'package:kreatif_klinik/core/utils/currency_formatter.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/models/order.dart';
import 'package:kreatif_klinik/data/repositories/settings_repository.dart';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<File> generateOrderInvoice(Order order) async {
    final pdf = pw.Document();
    final settings = await _settingsRepository.getAllSettings();
    final storeName = settings[AppConstants.keyStoreName] ?? AppConstants.defaultStoreName;
    final storeAddress = settings[AppConstants.keyStoreAddress] ?? AppConstants.defaultStoreAddress;
    final storePhone = settings[AppConstants.keyStorePhone] ?? AppConstants.defaultStorePhone;

    // Load logo if available (optional, for now use text)
    // final logo = await rootBundle.load('assets/icons/logoklinik.png');
    // final image = pw.MemoryImage(logo.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Thermal printer style roll
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text(storeAddress, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Telp: $storePhone', style: const pw.TextStyle(fontSize: 10)),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Invoice Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No: ${order.invoiceNumber}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(DateFormatter.formatDateTime(order.createdAt ?? DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Text('Pelanggan: ${order.customerName}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),

              // Items Table
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                    ),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Text('Subtotal', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  // Items
                  ...order.items!.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(item.serviceName, style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('${item.quantity} ${item.unit}', style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text(CurrencyFormatter.format(item.subtotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                      ],
                    );
                  }),
                ],
              ),
              pw.Divider(),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(CurrencyFormatter.format(order.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),

              // Payments
              if (order.paidAmount > 0) ...[
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Dibayar', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(CurrencyFormatter.format(order.paidAmount), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembali', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(CurrencyFormatter.format(order.paidAmount > order.totalAmount ? order.paidAmount - order.totalAmount : 0), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 5),
                if (order.remainingPayment > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Sisa Tagihan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red)),
                      pw.Text(CurrencyFormatter.format(order.remainingPayment), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red)),
                    ],
                  )
                else
                   pw.Center(child: pw.Text('LUNAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
              ],

               pw.SizedBox(height: 10),
               pw.Center(child: pw.Text('Terima Kasih', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${order.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
