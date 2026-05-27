import 'package:flutter/foundation.dart';
import 'package:kreatif_otopart/core/api/api_service.dart';
import 'package:kreatif_otopart/core/services/log_service.dart';
import 'package:kreatif_otopart/core/services/session_service.dart';
import 'package:kreatif_otopart/data/database/database_helper.dart';
import 'package:kreatif_otopart/data/models/customer.dart';
import 'package:kreatif_otopart/data/models/order.dart';
import 'package:kreatif_otopart/data/models/order_item.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/data/models/supplier.dart';

class SyncService {
  final ApiService _apiService;
  final DatabaseHelper _dbHelper;
  final LogService _logService = LogService();

  SyncService({
    required ApiService apiService,
    required DatabaseHelper dbHelper,
  })  : _apiService = apiService,
        _dbHelper = dbHelper;

  Future<void> _ensureAuthenticated() async {
    final session = await SessionService.getInstance();
    
    final customUrl = session.getBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      await _apiService.setBaseUrl(customUrl);
    }
    
    if (!session.hasCachedCredentials()) {
      throw Exception('Sesi kadaluarsa. Silakan login ulang untuk sinkronisasi.');
    }

    final username = session.getUsername()!;
    final password = session.getCachedPassword()!;

    final token = await _apiService.login(username, password);
    
    if (token != null) {
      await _apiService.setAuthToken(token);
    } else {
      throw Exception('Gagal login ke server. Periksa koneksi internet atau kredensial Anda.');
    }
  }

  // Upload unsynced orders
  Future<int> uploadOrders() async {
    await _ensureAuthenticated();

    final db = await _dbHelper.database;
    
    // Fetch branch info from settings
    final settingsResult = await db.query('app_settings');
    final settings = Map.fromEntries(
      settingsResult.map((e) => MapEntry(e['key'] as String, e['value'] as String)),
    );
    final branchId = settings[AppConstants.keyBranchId] ?? '';
    final branchCode = settings[AppConstants.keyBranchCode] ?? '';

    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (maps.isEmpty) return 0;

    int successCount = 0;

    for (final map in maps) {
      try {
        final order = Order.fromMap(map);
        
        final List<Map<String, dynamic>> itemMaps = await db.query(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [order.id],
        );
        final items = itemMaps.map((e) => OrderItem.fromMap(e)).toList();
        
        final payload = order.toMap();
        payload['items'] = items.map((e) => e.toMap()).toList();
        payload['branch_id'] = branchId;
        payload['branch_code'] = branchCode;
        
        final response = await _apiService.executeFlow('pos_sync_orders', 'pos', payload);
        
        if (response.data['code'] == 200) {
          final serverId = response.data['data']['data']['id']; 
          
          await db.update(
            'orders',
            {
              'is_synced': 1,
              'server_id': serverId,
            },
            where: 'id = ?',
            whereArgs: [order.id],
          );
          successCount++;
        }
      } catch (e) {
        await _logService.log('SYNC_ERROR', 'Order ${map['invoice_no']}: $e');
      }
    }

    return successCount;
  }

  // Upload unsynced purchase orders
  Future<int> uploadPurchaseOrders() async {
    await _ensureAuthenticated();

    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'purchase_orders',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (maps.isEmpty) return 0;

    int successCount = 0;

    for (final map in maps) {
      try {
        final payload = Map<String, dynamic>.from(map);
        
        final List<Map<String, dynamic>> itemMaps = await db.query(
          'purchase_order_items',
          where: 'purchase_order_id = ?',
          whereArgs: [map['id']],
        );
        payload['items'] = itemMaps;
        
        final response = await _apiService.executeFlow('pos_sync_purchase_orders', 'pos', payload);
        
        if (response.data['code'] == 200) {
          final serverId = response.data['data']['data']['id']; 
          
          await db.update(
            'purchase_orders',
            {
              'is_synced': 1,
              'server_id': serverId,
            },
            where: 'id = ?',
            whereArgs: [map['id']],
          );
          successCount++;
        }
      } catch (e) {
        await _logService.log('SYNC_ERROR', 'PurchaseOrder ${map['id']}: $e');
      }
    }

    return successCount;
  }

  // Download master data
  Future<void> downloadMasterData() async {
    await _ensureAuthenticated();
    await _downloadUnits();
    await _downloadProducts();
    await _downloadCustomers();
    await _downloadSuppliers();
  }
  
  Future<void> _downloadUnits() async {
    try {
      final response = await _apiService.executeFlow('pos_get_units', 'pos', {});
      if (response.data['code'] == 200) {
        final List<dynamic> data = response.data['data']['data'];
        final db = await _dbHelper.database;
        
        await db.transaction((txn) async {
          for (final item in data) {
            final List<Map<String, dynamic>> existing = await txn.query(
              'units',
              where: 'server_id = ?',
              whereArgs: [item['id']],
            );
            
            final unitMap = {
              'name': item['name'],
              'server_id': item['id'],
            };

            if (existing.isNotEmpty) {
              await txn.update('units', unitMap, where: 'server_id = ?', whereArgs: [item['id']]);
            } else {
              await txn.insert('units', unitMap);
            }
          }
        });
      }
    } catch (e) {
      await _logService.log('SYNC_ERROR', 'Units: $e');
    }
  }

  Future<void> _downloadProducts() async {
    try {
      final response = await _apiService.executeFlow('pos_get_products', 'pos', {});
      
      if (response.data['code'] == 200) {
        final List<dynamic> data = response.data['data']['data'];
        final db = await _dbHelper.database;

        await db.transaction((txn) async {
          for (final item in data) {
            final List<Map<String, dynamic>> existing = await txn.query(
              'products',
              where: 'server_id = ?',
              whereArgs: [item['id']],
            );

            final price = int.tryParse(item['price'].toString()) ?? 0;
            final cost = int.tryParse(item['cost'].toString()) ?? 0;
            final stock = double.tryParse(item['stock'].toString());

            final product = Product(
              name: item['name'],
              price: price,
              unit: item['unit'] ?? 'pcs',
              type: ProductTypeExtension.fromString(item['type'] ?? 'goods'),
              description: item['description'],
              cost: cost,
              stock: stock,
              imageUrl: item['image_url'],
              barcode: item['barcode'],
              serverId: item['id'],
            );

            if (existing.isNotEmpty) {
              final updateMap = product.toMap()..remove('id');
              await txn.update('products', updateMap, where: 'server_id = ?', whereArgs: [item['id']]);
            } else {
              await txn.insert('products', product.toMap());
            }
          }
        });
      }
    } catch (e) {
      await _logService.log('SYNC_ERROR', 'Products: $e');
    }
  }

  Future<void> _downloadCustomers() async {
    try {
      final response = await _apiService.executeFlow('pos_get_customers', 'pos', {});
      
      if (response.data['code'] == 200) {
        final List<dynamic> data = response.data['data']['data'];
        final db = await _dbHelper.database;

        await db.transaction((txn) async {
          for (final item in data) {
            final List<Map<String, dynamic>> existing = await txn.query(
              'customers',
              where: 'server_id = ?',
              whereArgs: [item['id']],
            );

            final customer = Customer(
              name: item['name'],
              phone: item['phone'],
              address: item['address'],
              notes: item['notes'],
              serverId: item['id'],
            );

            if (existing.isNotEmpty) {
              final updateMap = customer.toMap()..remove('id');
              await txn.update('customers', updateMap, where: 'server_id = ?', whereArgs: [item['id']]);
            } else {
              await txn.insert('customers', customer.toMap());
            }
          }
        });
      }
    } catch (e) {
      await _logService.log('SYNC_ERROR', 'Customers: $e');
    }
  }

  Future<void> _downloadSuppliers() async {
    try {
      final response = await _apiService.executeFlow('pos_get_suppliers', 'pos', {});
      
      if (response.data['code'] == 200) {
        final List<dynamic> data = response.data['data']['data'];
        final db = await _dbHelper.database;

        await db.transaction((txn) async {
          for (final item in data) {
            final List<Map<String, dynamic>> existing = await txn.query(
              'suppliers',
              where: 'server_id = ?',
              whereArgs: [item['id']],
            );

            final supplier = Supplier(
              name: item['name'],
              contactPerson: item['contact_person'],
              address: item['address'],
              phone: item['phone'],
              email: item['email'],
              serverId: item['id'],
            );

            if (existing.isNotEmpty) {
              final updateMap = supplier.toMap()..remove('id');
              await txn.update('suppliers', updateMap, where: 'server_id = ?', whereArgs: [item['id']]);
            } else {
              await txn.insert('suppliers', supplier.toMap());
            }
          }
        });
      }
    } catch (e) {
      await _logService.log('SYNC_ERROR', 'Suppliers: $e');
    }
  }
}
