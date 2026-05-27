import 'package:kreatif_otopart/data/database/database_helper.dart';
import 'package:kreatif_otopart/data/models/order.dart';
import 'package:kreatif_otopart/logic/cubits/report/report_state.dart';
import 'package:kreatif_otopart/data/models/order_item.dart';
import 'package:kreatif_otopart/data/models/purchase_order.dart';
import 'package:kreatif_otopart/data/models/purchase_order_item.dart';
import 'package:kreatif_otopart/data/models/supplier.dart';
import 'package:kreatif_otopart/data/models/product.dart';

class ReportRepository {
  final DatabaseHelper _databaseHelper;

  ReportRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Get orders within date range
  Future<List<Order>> getOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseHelper.database;

    // Set start to beginning of day and end to end of day
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toIso8601String();

    final result = await db.query(
      'orders',
      where: 'order_date >= ? AND order_date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'order_date DESC',
    );

    return result.map((map) => Order.fromMap(map)).toList();
  }

  /// Get report data for date range
  Future<ReportData> getReportData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseHelper.database;

    // Set start to beginning of day and end to end of day
    final start = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toIso8601String();

    // Get total orders and revenue (based on order_date)
    final summaryResult = await db.rawQuery('''
      SELECT
        COUNT(*) as total_orders,
        SUM(total_price) as total_revenue
      FROM orders
      WHERE order_date >= ? AND order_date <= ?
    ''', [start, end]);

    final summary = summaryResult.first;
    final totalOrders = (summary['total_orders'] as int?) ?? 0;
    final totalRevenue = (summary['total_revenue'] as int?) ?? 0;

    // Get total paid (based on payment_date from payments table)
    final paidResult = await db.rawQuery('''
      SELECT
        SUM(amount - COALESCE(change, 0)) as total_paid
      FROM payments
      WHERE payment_date >= ? AND payment_date <= ?
    ''', [start, end]);

    final totalPaid = (paidResult.first['total_paid'] as int?) ?? 0;

    // Get orders by status
    final statusResult = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM orders
      WHERE order_date >= ? AND order_date <= ?
      GROUP BY status
    ''', [start, end]);

    final ordersByStatus = <OrderStatus, int>{};
    int completedOrders = 0;
    int pendingOrders = 0;

    for (final row in statusResult) {
      final status = OrderStatusExtension.fromString(row['status'] as String);
      final count = row['count'] as int;
      ordersByStatus[status] = count;

      if (status == OrderStatus.done) {
        completedOrders = count;
      } else if (status != OrderStatus.done) {
        pendingOrders += count;
      }
    }

    // Get daily revenue (orders by order_date)
    final dailyOrderResult = await db.rawQuery('''
      SELECT
        DATE(order_date) as date,
        SUM(total_price) as revenue,
        COUNT(*) as order_count
      FROM orders
      WHERE order_date >= ? AND order_date <= ?
      GROUP BY DATE(order_date)
      ORDER BY date ASC
    ''', [start, end]);

    // Get daily payments (payments by payment_date)
    final dailyPaymentResult = await db.rawQuery('''
      SELECT
        DATE(payment_date) as date,
        SUM(amount - COALESCE(change, 0)) as paid
      FROM payments
      WHERE payment_date >= ? AND payment_date <= ?
      GROUP BY DATE(payment_date)
    ''', [start, end]);

    // Get total purchases
    final purchaseResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total_purchases
      FROM purchase_orders
      WHERE order_date >= ? AND order_date <= ? AND status != 'cancelled'
    ''', [start, end]);
    
    final totalPurchases = (purchaseResult.first['total_purchases'] as int?) ?? 0;

    // Get daily purchases
    final dailyPurchaseResult = await db.rawQuery('''
      SELECT 
        DATE(order_date) as date,
        SUM(total_amount) as purchases
      FROM purchase_orders
      WHERE order_date >= ? AND order_date <= ? AND status != 'cancelled'
      GROUP BY DATE(order_date)
    ''', [start, end]);

    // Create maps for quick lookup
    final dailyPayments = <String, int>{};
    for (final row in dailyPaymentResult) {
      final date = row['date'] as String;
      dailyPayments[date] = (row['paid'] as int?) ?? 0;
    }

    final dailyPurchases = <String, int>{};
    for (final row in dailyPurchaseResult) {
      final date = row['date'] as String;
      dailyPurchases[date] = (row['purchases'] as int?) ?? 0;
    }

    // Combine orders, payments, and purchases data
    // Start with dates from orders
    final dailyDataMap = <String, DailyRevenue>{};

    for (final row in dailyOrderResult) {
      final dateStr = row['date'] as String;
      final revenue = (row['revenue'] as int?) ?? 0;
      dailyDataMap[dateStr] = DailyRevenue(
        date: DateTime.parse(dateStr),
        revenue: revenue,
        orderCount: (row['order_count'] as int?) ?? 0,
        paid: dailyPayments[dateStr] ?? 0,
        purchases: dailyPurchases[dateStr] ?? 0,
        profit: revenue - (dailyPurchases[dateStr] ?? 0),
      );
    }

    // Add days that have payments but no orders
    for (final entry in dailyPayments.entries) {
      if (!dailyDataMap.containsKey(entry.key)) {
        dailyDataMap[entry.key] = DailyRevenue(
          date: DateTime.parse(entry.key),
          revenue: 0,
          orderCount: 0,
          paid: entry.value,
          purchases: dailyPurchases[entry.key] ?? 0,
          profit: 0 - (dailyPurchases[entry.key] ?? 0),
        );
      }
    }

    // Add days that have purchases but no orders or payments
    for (final entry in dailyPurchases.entries) {
      if (!dailyDataMap.containsKey(entry.key)) {
        dailyDataMap[entry.key] = DailyRevenue(
          date: DateTime.parse(entry.key),
          revenue: 0,
          orderCount: 0,
          paid: dailyPayments[entry.key] ?? 0,
          purchases: entry.value,
          profit: 0 - entry.value,
        );
      }
    }

    final dailyRevenue = dailyDataMap.values.toList();

    // Sort by date
    dailyRevenue.sort((a, b) => a.date.compareTo(b.date));

    // Get top services
    final serviceResult = await db.rawQuery('''
      SELECT
        oi.service_name,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.subtotal) as total_revenue,
        COUNT(DISTINCT oi.order_id) as order_count
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      WHERE o.order_date >= ? AND o.order_date <= ?
      GROUP BY oi.service_name
      ORDER BY total_revenue DESC
      LIMIT 10
    ''', [start, end]);

    final topServices = serviceResult.map((row) {
      return ServiceSummary(
        serviceName: row['service_name'] as String,
        totalQuantity: ((row['total_quantity'] as num?) ?? 0).toInt(),
        totalRevenue: (row['total_revenue'] as int?) ?? 0,
        orderCount: (row['order_count'] as int?) ?? 0,
      );
    }).toList();

    return ReportData(
      startDate: startDate,
      endDate: endDate,
      totalOrders: totalOrders,
      completedOrders: completedOrders,
      pendingOrders: pendingOrders,
      totalRevenue: totalRevenue,
      totalPaid: totalPaid,
      totalUnpaid: totalRevenue - totalPaid,
      totalPurchases: totalPurchases,
      totalProfit: totalRevenue - totalPurchases,
      ordersByStatus: ordersByStatus,
      dailyRevenue: dailyRevenue,
      topServices: topServices,
    );
  }

  /// Get orders with items for export
  Future<List<Order>> getOrdersWithItemsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseHelper.database;
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toIso8601String();

    // Get orders
    final orderMaps = await db.query(
      'orders',
      where: 'order_date >= ? AND order_date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'order_date DESC',
    );

    final orders = <Order>[];

    for (final map in orderMaps) {
      final order = Order.fromMap(map);
      
      // Get items for this order
      final itemMaps = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      final items = itemMaps.map((m) => OrderItem.fromMap(m)).toList();
      orders.add(order.copyWith(items: items));
    }

    return orders;
  }

  /// Get purchase orders with items for export
  Future<List<PurchaseOrder>> getPurchasesWithItemsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _databaseHelper.database;
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999).toIso8601String();

    // Get purchases
    final purchaseMaps = await db.query(
      'purchase_orders',
      where: 'order_date >= ? AND order_date <= ? AND status != ?',
      whereArgs: [startStr, endStr, 'cancelled'],
      orderBy: 'order_date DESC',
    );

    final purchases = <PurchaseOrder>[];

    for (final map in purchaseMaps) {
      // Need provider to map supplier, but for report simple data might be enough
      // or we just fetch supplier name if needed. 
      // For now, let's just map the PO.
      // Ideally we should join supplier table or fetch it.
      
      var purchase = PurchaseOrder.fromMap(map);
      
      // Fetch Supplier
      final supplierMaps = await db.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [purchase.supplierId],
      );
      
      if (supplierMaps.isNotEmpty) {
        final supplier = Supplier.fromMap(supplierMaps.first);
        purchase = purchase.copyWith(supplier: supplier);
      }

      // Get items
      final itemMaps = await db.query(
        'purchase_order_items',
        where: 'purchase_order_id = ?',
        whereArgs: [purchase.id],
      );

      final items = itemMaps.map((m) => PurchaseOrderItem.fromMap(m)).toList();
      purchases.add(purchase.copyWith(items: items));
    }

    return purchases;
  }

  /// Get all products for stock report
  Future<List<Product>> getAllProducts() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }
}
