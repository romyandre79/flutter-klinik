import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_pos_printer_platform/flutter_pos_printer_platform.dart'; // Removed
import 'package:kreatif_pos/core/services/printer_service.dart';
import 'package:kreatif_pos/data/models/order.dart';
import 'package:kreatif_pos/logic/cubits/printer/printer_state.dart';

class PrinterCubit extends Cubit<PrinterState> {
  final PrinterService _printerService;
  StreamSubscription<List<PrinterInfo>>? _scanSubscription;
  List<PrinterInfo> _scannedDevices = [];

  PrinterCubit({PrinterService? printerService})
      : _printerService = printerService ?? PrinterService(),
        super(const PrinterInitial());

  String get currentPaperSize => _printerService.paperSize;

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    return super.close();
  }

  /// Initialize and load settings
  Future<void> initialize() async {
    await _printerService.initialize();
    await loadDevices();
  }

  /// Load paired devices
  Future<void> loadDevices() async {
    _scanSubscription?.cancel();
    _scannedDevices.clear();
    
    emit(const PrinterLoading());

    try {
      final isBluetoothAvailable = await _printerService.isBluetoothAvailable();
      final paperSize = await _printerService.getSavedPaperSize();
      PrinterInfo? connectedDevice = _printerService.connectedDevice;
      
      // Determine what to scan
      // PrinterService handles logic internally now.

      // Initial emit
       emit(PrinterDevicesLoaded(
        devices: [..._scannedDevices],
        connectedDevice: connectedDevice,
        paperSize: paperSize,
        bluetoothEnabled: isBluetoothAvailable,
        savedPrinterMac: connectedDevice?.address,
      ));

      // Start scanning
      _scanSubscription = _printerService.scanDevices().listen((devices) {
          _scannedDevices = devices;
          // Emit update
           emit(PrinterDevicesLoaded(
            devices: [..._scannedDevices],
            connectedDevice: _printerService.connectedDevice,
            paperSize: paperSize,
            bluetoothEnabled: isBluetoothAvailable,
            savedPrinterMac: _printerService.connectedDevice?.address,
          ));
      }, onError: (e) {
        // scan failed
      });

    } catch (e) {
      emit(const PrinterDevicesLoaded(devices: []));
    }
  }

  /// Connect to device
  Future<void> connectDevice(PrinterInfo device) async { // Changed type to PrinterInfo
    emit(PrinterConnecting(device.name));

    try {
      final success = await _printerService.connect(device);
      if (success) {
        emit(PrinterConnected(device.name));
        await loadDevices(); 
      } else {
        emit(const PrinterError('Gagal terhubung ke printer'));
        await loadDevices();
      }
    } catch (e) {
      emit(PrinterError(e.toString().replaceAll('Exception: ', '')));
      await loadDevices();
    }
  }

  /// Disconnect from device
  Future<void> disconnectDevice() async {
    emit(const PrinterLoading());

    try {
      await _printerService.disconnect();
      emit(const PrinterDisconnected());
      await loadDevices();
    } catch (e) {
      emit(PrinterError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Print receipt
  Future<void> printReceipt(Order order) async {
    emit(const PrinterPrinting());

    try {
      final success = await _printerService.printReceipt(order);
      if (success) {
        emit(const PrinterPrintSuccess('Struk berhasil dicetak'));
      } else {
        emit(const PrinterError('Gagal mencetak struk'));
      }
    } catch (e) {
      emit(PrinterError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Set paper size
  Future<void> setPaperSize(String size) async {
    await _printerService.setPaperSize(size);
    // Refresh to update state
    if (state is PrinterDevicesLoaded) {
      final curr = state as PrinterDevicesLoaded;
      emit(PrinterDevicesLoaded(
        devices: curr.devices,
        connectedDevice: curr.connectedDevice,
        paperSize: size,
        bluetoothEnabled: curr.bluetoothEnabled,
        savedPrinterMac: curr.savedPrinterMac
      ));
    } else {
       await loadDevices();
    }
  }

  /// Print test page
  Future<void> printTest() async {
    emit(const PrinterPrinting());

    try {
      final success = await _printerService.printTest();
      if (success) {
        emit(const PrinterPrintSuccess('Test print berhasil'));
      } else {
        emit(const PrinterError('Gagal mencetak test'));
      }
      await loadDevices();
    } catch (e) {
      emit(PrinterError(e.toString().replaceAll('Exception: ', '')));
       await loadDevices();
    }
  }
}
