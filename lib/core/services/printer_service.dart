import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:kreatif_pos/data/models/order.dart';
import 'package:kreatif_pos/core/services/store_print.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart' as ftp;
import 'package:flutter_thermal_printer/utils/printer.dart' as ftp_utils;
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterType { bluetooth, usb, network }

class PrinterInfo {
  final String name;
  final String address;
  final PrinterType type;
  final String? vendorId;
  final String? productId;
  
  // Internal source object (BluetoothInfo or ftp_utils.Printer)
  final dynamic source;

  PrinterInfo({
    required this.name,
    required this.address,
    this.type = PrinterType.bluetooth,
    this.vendorId,
    this.productId,
    this.source,
  });
}

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  // SharedPreferences keys
  static const String _keyPrinterName = 'printer_name';
  static const String _keyPrinterAddress = 'printer_address';
  static const String _keyPrinterType = 'printer_type';
  static const String _keyPrinterVendorId = 'printer_vendor_id';
  static const String _keyPrinterProductId = 'printer_product_id';
  static const String _keyPaperSize = 'paper_size';

  PrinterInfo? _connectedDevice;
  String _paperSize = '58'; // default 58mm

  bool get isConnected => _connectedDevice != null;
  String? get connectedDeviceName => _connectedDevice?.name;
  PrinterInfo? get connectedDevice => _connectedDevice;
  String get paperSize => _paperSize;

  // Stream controller for scanning (unified)
  final _scanController = StreamController<List<PrinterInfo>>.broadcast();

  /// Initialize printer service - load saved settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyPrinterName);
    final address = prefs.getString(_keyPrinterAddress);
    final typeIndex = prefs.getInt(_keyPrinterType);
    final vendorId = prefs.getString(_keyPrinterVendorId);
    final productId = prefs.getString(_keyPrinterProductId);
    
    _paperSize = prefs.getString(_keyPaperSize) ?? '58';

    if (name != null && address != null && typeIndex != null) {
      if (typeIndex >= 0 && typeIndex < PrinterType.values.length) {
        final type = PrinterType.values[typeIndex];
        // We can't fully reconstruct the 'source' object here easily, 
        // but for reconnection we might need to scan first or just try connecting by address/ID.
        // For now, we restore the info.
        _connectedDevice = PrinterInfo(
          name: name,
          address: address,
          type: type,
          vendorId: vendorId,
          productId: productId,
          source: null, // Will need to be populated on connect/scan
        );
      }
    }
  }

  /// Check if Bluetooth is available (Mobile only)
  Future<bool> isBluetoothAvailable() async {
    if (Platform.isWindows) return true; // USB assumed available
    return await PrintBluetoothThermal.bluetoothEnabled;
  }

  /// Get available devices
  Stream<List<PrinterInfo>> scanDevices() {
    if (Platform.isWindows) {
      _scanWindowsPrinters();
      return _scanController.stream;
    } else {
      _scanMobilePrinters();
      return _scanController.stream;
    }
  }

  Future<void> _scanWindowsPrinters() async {
    // Windows: Use flutter_thermal_printer for everything (USB, BLE, NETWORK)
    try {
      await ftp.FlutterThermalPrinter.instance.getPrinters(connectionTypes: [
        ftp_utils.ConnectionType.USB,
        ftp_utils.ConnectionType.BLE,
        ftp_utils.ConnectionType.NETWORK,
      ]);
      
      // We listen to the stream, which will emit the updated list
      ftp.FlutterThermalPrinter.instance.devicesStream.listen((devices) {
        final infos = devices.map((d) => _mapFtpPrinterToInfo(d)).toList();
        _scanController.add(infos);
      });
    } catch (e) {
      debugPrint('Windows Scan Error: $e');
      _scanController.add([]);
    }
  }

  Future<void> _scanMobilePrinters() async {
    // Mobile Strategy:
    // 1. Bluetooth -> print_bluetooth_thermal (reliable source)
    // 2. USB & Network -> flutter_thermal_printer
    
    List<PrinterInfo> mergedList = [];

    // Stream for flutter_thermal_printer (USB/Network/BLE)
    // We filter out BLE from here if we want to rely strictly on print_bluetooth_thermal, 
    // or we can include it. Let's include USB and Network.
    try {
       await ftp.FlutterThermalPrinter.instance.getPrinters(connectionTypes: [
        ftp_utils.ConnectionType.USB,
        ftp_utils.ConnectionType.NETWORK,
        // ftp_utils.ConnectionType.BLE // Optional: Enable if we want to try BLE from this lib too
      ]);
      
      final ftpStream = ftp.FlutterThermalPrinter.instance.devicesStream;
      
      // One-off fetch for classic bluetooth
      List<PrinterInfo> classicBluetoothDevices = [];
      try {
        final devices = await PrintBluetoothThermal.pairedBluetooths;
        classicBluetoothDevices = devices.map((d) => PrinterInfo(
          name: d.name,
          address: d.macAdress,
          type: PrinterType.bluetooth,
          source: d,
        )).toList();
      } catch (e) {
        debugPrint('Mobile Bluetooth Scan Error: $e');
      }

      // Merge and emit
      // Since ftpStream is a stream, we rely on its events. 
      // But we need to combine it with the static list of bluetooth devices.
      ftpStream.listen((ftpDevices) {
        final ftpInfos = ftpDevices.map((d) => _mapFtpPrinterToInfo(d)).toList();
        
        // Combine lists (avoid duplicates if necessary, though types likely differ)
        final combined = [...classicBluetoothDevices, ...ftpInfos];
        _scanController.add(combined);
      });

      // Also trigger an immediate emit in case stream doesn't fire immediately if empty
      if (mergedList.isEmpty) {
         _scanController.add([...classicBluetoothDevices]);
      }

    } catch (e) {
      debugPrint('Mobile Scan Error: $e');
      _scanController.add([]);
    }
  }
  
  PrinterInfo _mapFtpPrinterToInfo(ftp_utils.Printer d) {
    PrinterType type;
    switch (d.connectionType) {
      case ftp_utils.ConnectionType.USB:
        type = PrinterType.usb;
        break;
      case ftp_utils.ConnectionType.BLE:
        type = PrinterType.bluetooth;
        break;
      case ftp_utils.ConnectionType.NETWORK:
        type = PrinterType.network;
        break;
      default:
        type = PrinterType.usb; // fallback
    }
    
    return PrinterInfo(
      name: d.name ?? 'Unknown',
      address: d.address ?? '',
      type: type,
      vendorId: d.vendorId,
      productId: d.productId,
      source: d, // Keep the source!
    );
  }

  /// Connect to device
  Future<bool> connect(PrinterInfo device) async {
    try {
      // If it's a flutter_thermal_printer device (Window or Mobile USB/Network)
      if (device.source is ftp_utils.Printer) {
         final printer = device.source as ftp_utils.Printer;
         final result = await ftp.FlutterThermalPrinter.instance.connect(printer);
         if (result) {
           _connectedDevice = device;
           await _saveSettings(device);
         }
         return result;
      }
      // If it's a print_bluetooth_thermal device (Mobile Bluetooth)
      else if (device.source is BluetoothInfo || (Platform.isAndroid || Platform.isIOS) && device.type == PrinterType.bluetooth) {
         // Fallback: If source is null (from prefs), we rely on address for mobile bluetooth
         final result = await PrintBluetoothThermal.connect(macPrinterAddress: device.address);
         if (result) {
           _connectedDevice = device;
           await _saveSettings(device);
         }
         return result;
      }
      
      return false;
    } catch (e) {
      // debugPrint('Error connecting: $e');
      return false;
    }
  }

  Future<void> _saveSettings(PrinterInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterName, device.name);
    await prefs.setString(_keyPrinterAddress, device.address);
    await prefs.setInt(_keyPrinterType, device.type.index);
    if (device.vendorId != null) await prefs.setString(_keyPrinterVendorId, device.vendorId!);
    if (device.productId != null) await prefs.setString(_keyPrinterProductId, device.productId!);
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      if (Platform.isWindows) {
         if (_connectedDevice!.source != null) {
             // await ftp.FlutterThermalPrinter.instance.disconnect(_connectedDevice!.source);
             // Library seems to lack explicit disconnect for USB sometimes or it's named differently?
             // Checking API... disconnect(Printer) exists.
             await ftp.FlutterThermalPrinter.instance.disconnect(_connectedDevice!.source);
         }
      } else {
        await PrintBluetoothThermal.disconnect;
      }
      
      _connectedDevice = null;
      // Optionally clear prefs
    }
  }

  /// Set paper size ('58' or '80')
  Future<void> setPaperSize(String size) async {
    _paperSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaperSize, size);
  }

  /// Get saved paper size
  Future<String> getSavedPaperSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPaperSize) ?? '58';
  }

  /// Get PaperSize enum from string
  PaperSize getPaperSizeEnum() {
    return _paperSize == '80' ? PaperSize.mm80 : PaperSize.mm58;
  }

  /// Ensure connected
  Future<bool> ensureConnected() async {
    if (_connectedDevice != null) {
      // Use connection check API if available?
       if (Platform.isWindows) {
         // TODO: Check status
         return true;
       } else {
         final connected = await PrintBluetoothThermal.connectionStatus;
         if (connected) return true;
       }
    }
    
    // Try reconnect from preferences?
    // On Windows reconnection requires scanning to get the handle usually.
    // On Mobile we can connect by MAC.
    await initialize();
    if (_connectedDevice != null && !Platform.isWindows) {
       return await connect(_connectedDevice!);
    }
    
    return false;
  }

  /// Print order receipt
  Future<bool> printReceipt(Order order) async {
    if (!await ensureConnected()) {
      throw Exception('Printer tidak terhubung. Silakan hubungkan printer di Settings.');
    }

    try {
      final bytes = await StorePrint.instance.printOrderReceipt(
        order,
        paperSize: getPaperSizeEnum(),
        paperSizeMm: _paperSize,
      );
      
      return await _printBytes(bytes);
    } catch (e) {
      throw Exception('Gagal mencetak: ${e.toString()}');
    }
  }

  /// Print test page
  Future<bool> printTest() async {
     if (!await ensureConnected()) {
      throw Exception('Printer tidak terhubung. Silakan hubungkan printer di Settings.');
    }

    try {
      final bytes = await StorePrint.instance.printTest(
        paperSize: getPaperSizeEnum(),
        paperSizeMm: _paperSize,
      );
      
      return await _printBytes(bytes);
    } catch (e) {
      throw Exception('Gagal mencetak: ${e.toString()}');
    }
  }

  Future<bool> _printBytes(List<int> bytes) async {
    if (_connectedDevice == null) return false;

    try {
      // 1. Try flutter_thermal_printer source
      if (_connectedDevice!.source is ftp_utils.Printer) {
         await ftp.FlutterThermalPrinter.instance.printData(_connectedDevice!.source, bytes);
         return true;
      }
      
      // 2. Try Mobile Bluetooth (print_bluetooth_thermal)
      if (Platform.isAndroid || Platform.isIOS) {
          // If type is bluetooth, assume print_bluetooth_thermal
          if (_connectedDevice!.type == PrinterType.bluetooth) {
             return await PrintBluetoothThermal.writeBytes(bytes);
          }
      }
      
      // 3. Fallback: If we have a Windows device with null source (restarted app), we usually fail.
      // But maybe we can try to find it? For now return false.
      
      return false;
    } catch (e) {
      debugPrint('Print Error: $e');
      return false;
    }
  }
}
