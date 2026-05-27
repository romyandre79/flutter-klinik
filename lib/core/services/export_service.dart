import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;
import 'package:kreatif_pos/data/models/order.dart';
import 'package:kreatif_pos/data/models/purchase_order.dart';
import 'package:kreatif_pos/data/models/product.dart';
import 'package:kreatif_pos/core/utils/currency_formatter.dart';
import 'package:kreatif_pos/core/utils/date_formatter.dart';
import 'package:kreatif_pos/logic/cubits/report/report_state.dart';


class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export orders to Excel
  Future<String> exportOrdersToExcel(
    List<Order> orders,
    ReportData reportData,
  ) async {
    final excel = Excel.createExcel();

    // Sheet 1: Summary
    _createSummarySheet(excel, reportData);

    // Sheet 2: Orders
    _createOrdersSheet(excel, orders);

    // Sheet 3: Service Summary
    _createServiceSummarySheet(excel, reportData);

    // Remove default sheet
    excel.delete('Sheet1');

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'Laporan_${DateFormatter.formatDateCompact(reportData.startDate)}_${DateFormatter.formatDateCompact(reportData.endDate)}.xlsx';
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }

    throw Exception('Gagal membuat file Excel');
  }

  void _createSummarySheet(Excel excel, ReportData reportData) {
    final sheet = excel['Ringkasan'];

    // Title
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('LAPORAN TRANSAKSI');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'Periode: ${DateFormatter.formatDate(reportData.startDate)} - ${DateFormatter.formatDate(reportData.endDate)}');

    // Summary data
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Ringkasan');

    sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('Total Penjualan');
    sheet.cell(CellIndex.indexByString('B6')).value = IntCellValue(reportData.totalOrders);

    sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('Penjualan Selesai');
    sheet.cell(CellIndex.indexByString('B7')).value = IntCellValue(reportData.completedOrders);

    sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('Penjualan Pending');
    sheet.cell(CellIndex.indexByString('B8')).value = IntCellValue(reportData.pendingOrders);

    sheet.cell(CellIndex.indexByString('A10')).value = TextCellValue('Total Omzet');
    sheet.cell(CellIndex.indexByString('B10')).value =
        TextCellValue(CurrencyFormatter.format(reportData.totalRevenue));

    sheet.cell(CellIndex.indexByString('A11')).value = TextCellValue('Total Dibayar');
    sheet.cell(CellIndex.indexByString('B11')).value =
        TextCellValue(CurrencyFormatter.format(reportData.totalPaid));

    sheet.cell(CellIndex.indexByString('A12')).value = TextCellValue('Total Belum Dibayar');
    sheet.cell(CellIndex.indexByString('B12')).value =
        TextCellValue(CurrencyFormatter.format(reportData.totalUnpaid));
        
    sheet.cell(CellIndex.indexByString('A13')).value = TextCellValue('Total Pembelian');
    sheet.cell(CellIndex.indexByString('B13')).value =
        TextCellValue(CurrencyFormatter.format(reportData.totalPurchases));

    sheet.cell(CellIndex.indexByString('A14')).value = TextCellValue('Total Laba Bersih');
    sheet.cell(CellIndex.indexByString('B14')).value =
        TextCellValue(CurrencyFormatter.format(reportData.totalProfit));

    // Daily revenue
    sheet.cell(CellIndex.indexByString('A16')).value = TextCellValue('Laporan Harian');

    sheet.cell(CellIndex.indexByString('A17')).value = TextCellValue('Tanggal');
    sheet.cell(CellIndex.indexByString('B17')).value = TextCellValue('Jumlah Penjualan');
    sheet.cell(CellIndex.indexByString('C17')).value = TextCellValue('Omzet');
    sheet.cell(CellIndex.indexByString('D17')).value = TextCellValue('Dibayar');
    sheet.cell(CellIndex.indexByString('E17')).value = TextCellValue('Pembelian');
    sheet.cell(CellIndex.indexByString('F17')).value = TextCellValue('Laba');

    int row = 18;
    for (final daily in reportData.dailyRevenue) {
      sheet.cell(CellIndex.indexByString('A$row')).value =
          TextCellValue(DateFormatter.formatDate(daily.date));
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(daily.orderCount);
      sheet.cell(CellIndex.indexByString('C$row')).value =
          TextCellValue(CurrencyFormatter.format(daily.revenue));
      sheet.cell(CellIndex.indexByString('D$row')).value =
          TextCellValue(CurrencyFormatter.format(daily.paid));
      sheet.cell(CellIndex.indexByString('E$row')).value =
          TextCellValue(CurrencyFormatter.format(daily.purchases));
      sheet.cell(CellIndex.indexByString('F$row')).value =
          TextCellValue(CurrencyFormatter.format(daily.profit));
      row++;
    }
  }

  void _createOrdersSheet(Excel excel, List<Order> orders) {
    final sheet = excel['Daftar Penjualan'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No Invoice');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Tanggal');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Pelanggan');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('No HP');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Status');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Total');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('Dibayar');
    sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue('Kurang');

    int row = 2;
    for (final order in orders) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(order.invoiceNo);
      sheet.cell(CellIndex.indexByString('B$row')).value =
          TextCellValue(DateFormatter.formatDateTime(order.orderDate));
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(order.customerName);
      sheet.cell(CellIndex.indexByString('D$row')).value =
          TextCellValue(order.customerPhone ?? '-');
      sheet.cell(CellIndex.indexByString('E$row')).value =
          TextCellValue(order.status.displayName);
      sheet.cell(CellIndex.indexByString('F$row')).value =
          TextCellValue(CurrencyFormatter.format(order.totalPrice));
      sheet.cell(CellIndex.indexByString('G$row')).value =
          TextCellValue(CurrencyFormatter.format(order.paid));
      sheet.cell(CellIndex.indexByString('H$row')).value =
          TextCellValue(CurrencyFormatter.format(order.remainingPayment));
      row++;
    }
  }

  void _createServiceSummarySheet(Excel excel, ReportData reportData) {
    final sheet = excel['Layanan Populer'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Nama Layanan');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Jumlah Penjualan');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Total Qty');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Total Pendapatan');

    int row = 2;
    for (final service in reportData.topServices) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(service.serviceName);
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(service.orderCount);
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(service.totalQuantity);
      sheet.cell(CellIndex.indexByString('D$row')).value =
          TextCellValue(CurrencyFormatter.format(service.totalRevenue));
      row++;
    }
  }

  /// Share exported file
  Future<void> shareFile(String filePath) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], text: 'Laporan Transaksi'),
    );
  }

  /// Export Sales Detail to Excel
  Future<String> exportSalesDetailToExcel(
    List<Order> orders,
    ReportData reportData,
  ) async {
    final excel = Excel.createExcel();

    // Sheet 1: Sales Detail
    final sheet = excel['Detail Penjualan'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No Invoice');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Tanggal');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Pelanggan');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Item');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Qty');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Satuan');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('Harga Satuan');
    sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue('Subtotal');
    sheet.cell(CellIndex.indexByString('I1')).value = TextCellValue('Total Transaksi');

    int row = 2;
    for (final order in orders) {
      // If items are empty, at least show the order row
      if (order.items == null || order.items!.isEmpty) {
        sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(order.invoiceNo);
        sheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(DateFormatter.formatDateTime(order.orderDate));
        sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(order.customerName);
        sheet.cell(CellIndex.indexByString('I$row')).value =
            TextCellValue(CurrencyFormatter.format(order.totalPrice));
        row++;
      } else {
        bool firstItem = true;
        for (final item in order.items!) {
          sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(order.invoiceNo);
          sheet.cell(CellIndex.indexByString('B$row')).value =
              TextCellValue(DateFormatter.formatDateTime(order.orderDate));
          sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(order.customerName);
          
          sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(item.serviceName);
          sheet.cell(CellIndex.indexByString('E$row')).value = DoubleCellValue(item.quantity);
          sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(item.unit);
          sheet.cell(CellIndex.indexByString('G$row')).value =
              TextCellValue(CurrencyFormatter.format(item.pricePerUnit));
          sheet.cell(CellIndex.indexByString('H$row')).value =
              TextCellValue(CurrencyFormatter.format(item.subtotal));
          
          if (firstItem) {
             sheet.cell(CellIndex.indexByString('I$row')).value =
                TextCellValue(CurrencyFormatter.format(order.totalPrice));
             firstItem = false;
          }
          row++;
        }
      }
    }

    // Remove default sheet
    excel.delete('Sheet1');

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'Laporan_Penjualan_Detail_${DateFormatter.formatDateCompact(reportData.startDate)}_${DateFormatter.formatDateCompact(reportData.endDate)}.xlsx';
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }

    throw Exception('Gagal membuat file Excel Detail Penjualan');
  }

  /// Export Purchase Detail to Excel
  Future<String> exportPurchaseDetailToExcel(
    List<PurchaseOrder> purchases,
    ReportData reportData,
  ) async {
    final excel = Excel.createExcel();

    // Sheet 1: Purchase Detail
    final sheet = excel['Detail Pembelian'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Supplier');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Tanggal');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Status');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Item');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Qty');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Satuan');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('Harga Satuan');
    sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue('Subtotal');
    sheet.cell(CellIndex.indexByString('I1')).value = TextCellValue('Total Transaksi');

    int row = 2;
    for (final purchase in purchases) {
      final supplierName = purchase.supplier?.name ?? 'Unknown Supplier';
      
      if (purchase.items.isEmpty) {
        sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(supplierName);
        sheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(DateFormatter.formatDate(purchase.orderDate));
        sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(purchase.statusDisplay);
        sheet.cell(CellIndex.indexByString('I$row')).value =
            TextCellValue(CurrencyFormatter.format(purchase.totalAmount));
        row++;
      } else {
        bool firstItem = true;
        for (final item in purchase.items) {
          sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(supplierName);
          sheet.cell(CellIndex.indexByString('B$row')).value =
              TextCellValue(DateFormatter.formatDate(purchase.orderDate));
          sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(purchase.statusDisplay);
          
          sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(item.itemName);
          sheet.cell(CellIndex.indexByString('E$row')).value = IntCellValue(item.quantity);
          sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(item.unit);
          sheet.cell(CellIndex.indexByString('G$row')).value =
              TextCellValue(CurrencyFormatter.format(item.cost));
          sheet.cell(CellIndex.indexByString('H$row')).value =
              TextCellValue(CurrencyFormatter.format(item.subtotal));
          
          if (firstItem) {
             sheet.cell(CellIndex.indexByString('I$row')).value =
                TextCellValue(CurrencyFormatter.format(purchase.totalAmount));
             firstItem = false;
          }
          row++;
        }
      }
    }

    // Remove default sheet
    excel.delete('Sheet1');

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'Laporan_Pembelian_Detail_${DateFormatter.formatDateCompact(reportData.startDate)}_${DateFormatter.formatDateCompact(reportData.endDate)}.xlsx';
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }

    throw Exception('Gagal membuat file Excel Detail Pembelian');
  }

  /// Export Stock Report to Excel
  Future<String> exportStockReportToExcel(
    List<Product> products,
  ) async {
    final excel = Excel.createExcel();

    // Sheet 1: Stock Report
    final sheet = excel['Stok Produk'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Nama Produk');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Kategori');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Stok');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Satuan');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Harga Modal');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Harga Jual');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('Nilai Aset (Modal)');
    sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue('Nilai Jual');

    int row = 2;
    int totalAssetValue = 0;
    int totalSalesValue = 0;

    for (final product in products) {
      // Only include goods or products with stock tracking?
      // Usually user wants to see all products, but stock only relevant for goods.
      
      final stock = product.stock ?? 0;
      final assetValue = (stock * product.cost).round();
      final salesValue = (stock * product.price).round();

      totalAssetValue += assetValue;
      totalSalesValue += salesValue;

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(product.name);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(product.type.displayName);
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(stock);
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(product.unit);
      
      sheet.cell(CellIndex.indexByString('E$row')).value =
          TextCellValue(CurrencyFormatter.format(product.cost));
      sheet.cell(CellIndex.indexByString('F$row')).value =
          TextCellValue(CurrencyFormatter.format(product.price));
      
      sheet.cell(CellIndex.indexByString('G$row')).value =
          TextCellValue(CurrencyFormatter.format(assetValue));
      sheet.cell(CellIndex.indexByString('H$row')).value =
          TextCellValue(CurrencyFormatter.format(salesValue));
      
      row++;
    }

    // Add totals row
    row++;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('TOTAL');
    sheet.cell(CellIndex.indexByString('G$row')).value =
        TextCellValue(CurrencyFormatter.format(totalAssetValue));
    sheet.cell(CellIndex.indexByString('H$row')).value =
        TextCellValue(CurrencyFormatter.format(totalSalesValue));

    // Remove default sheet
    excel.delete('Sheet1');

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        'Laporan_Stok_${DateFormatter.formatDateCompact(DateTime.now())}.xlsx';
    final filePath = '${directory.path}/$fileName';

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }

    throw Exception('Gagal membuat file Excel Laporan Stok');
  }

  /// Save Excel file (Handles both Mobile and Desktop)
  Future<String?> saveExcelFile(Excel excel, String fileName) async {
    final fileBytes = excel.save();
    if (fileBytes == null) return null;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Excel',
        fileName: fileName,
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        // Ensure extension
        String path = outputFile;
        if (!path.endsWith('.xlsx')) {
          path = '$path.xlsx';
        }

        final file = File(path);
        await file.writeAsBytes(fileBytes);
        return path;
      }
      return null; // User canceled
    } else {
      // Mobile
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }
  }
}
