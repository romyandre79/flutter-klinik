import 'dart:io';
import 'package:excel/excel.dart';
import 'package:kreatif_pos/data/models/product.dart';
import 'package:kreatif_pos/data/models/customer.dart';
import 'package:kreatif_pos/data/models/supplier.dart';

class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  /// Parse products from Excel file
  /// Expected columns: Name, Description, Price, Cost, Stock, Unit, Type (Barang/Jasa), Barcode
  Future<List<Product>> parseProductsFromExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<Product> products = [];

    // Assume data is in the first sheet
    final table = excel.tables[excel.tables.keys.first];

    if (table == null || table.maxRows < 2) {
      throw Exception('Format Excel tidak valid atau kosong');
    }

    // Iterate rows, skip header (index 0)
    for (int i = 1; i < table.maxRows; i++) {
      final row = table.row(i);
      
      // Check if row is empty or invalid
      if (row.isEmpty || row[0] == null) continue;

      try {
        // 0: Name (Required)
        final name = _getCellValue(row[0]);
        if (name.isEmpty) continue;

        // 1: Description
        final description = _getCellValue(row[1]);

        // 2: Price (Required)
        final price = _getIntValue(row[2]) ?? 0;

        // 3: Cost
        final cost = _getIntValue(row[3]) ?? 0;

        // 4: Stock
        final stock = _getDoubleValue(row[4]) ?? 0.0;

        // 5: Unit (Required)
        final unit = _getCellValue(row[5]);
        
        // 6: Type (Barang/Jasa)
        final typeStr = _getCellValue(row[6]);
        ProductType type = ProductType.goods;
        if (typeStr.toLowerCase().contains('jasa') || typeStr.toLowerCase().contains('service')) {
          type = ProductType.service;
        }

        // 7: Barcode
        final barcode = _getCellValue(row[7]);

        final product = Product(
          name: name,
          description: description,
          price: price,
          cost: cost,
          stock: stock,
          unit: unit.isEmpty ? 'pcs' : unit,
          type: type,
          barcode: barcode.isEmpty ? null : barcode,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        products.add(product);
      } catch (e) {
        // Skip invalid rows but continue
        print('Error parsing row $i: $e');
        continue;
      }
    }

    return products;
  }

  String _getCellValue(Data? cell) {
    if (cell == null) return '';
    return cell.value.toString();
  }

  int? _getIntValue(Data? cell) {
    if (cell == null) return null;
    if (cell.value is int) return cell.value as int;
    if (cell.value is double) return (cell.value as double).toInt();
    if (cell.value is String) return int.tryParse(cell.value as String);
    return null;
  }

  double? _getDoubleValue(Data? cell) {
    if (cell == null) return null;
    if (cell.value is double) return cell.value as double;
    if (cell.value is int) return (cell.value as int).toDouble();
    if (cell.value is String) return double.tryParse(cell.value as String);
    return null;
  }

  /// Parse customers from Excel file
  /// Expected columns: Name, Phone, Address, Notes
  Future<List<Customer>> parseCustomersFromExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<Customer> customers = [];
    final table = excel.tables[excel.tables.keys.first];

    if (table == null || table.maxRows < 2) {
      throw Exception('Format Excel tidak valid atau kosong');
    }

    for (int i = 1; i < table.maxRows; i++) {
      final row = table.row(i);
      if (row.isEmpty || row[0] == null) continue;

      try {
        final name = _getCellValue(row[0]);
        if (name.isEmpty) continue;

        final phone = _getCellValue(row[1]);
        final address = _getCellValue(row[2]);
        final notes = _getCellValue(row[3]);

        final customer = Customer(
          name: name,
          phone: phone,
          address: address,
          notes: notes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        customers.add(customer);
      } catch (e) {
        print('Error parsing customer row $i: $e');
        continue;
      }
    }
    return customers;
  }

  /// Parse suppliers from Excel file
  /// Expected columns: Name, Contact Person, Phone, Email, Address
  Future<List<Supplier>> parseSuppliersFromExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<Supplier> suppliers = [];
    final table = excel.tables[excel.tables.keys.first];

    if (table == null || table.maxRows < 2) {
      throw Exception('Format Excel tidak valid atau kosong');
    }

    for (int i = 1; i < table.maxRows; i++) {
      final row = table.row(i);
      if (row.isEmpty || row[0] == null) continue;

      try {
        final name = _getCellValue(row[0]);
        if (name.isEmpty) continue;

        final contactPerson = _getCellValue(row[1]);
        final phone = _getCellValue(row[2]);
        final email = _getCellValue(row[3]);
        final address = _getCellValue(row[4]);

        final supplier = Supplier(
          name: name,
          contactPerson: contactPerson,
          phone: phone,
          email: email,
          address: address,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        suppliers.add(supplier);
      } catch (e) {
        print('Error parsing supplier row $i: $e');
        continue;
      }
    }
    return suppliers;
  }
}
