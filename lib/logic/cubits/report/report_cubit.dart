import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_klinik/data/repositories/report_repository.dart';
import 'package:kreatif_klinik/core/services/export_service.dart';
import 'package:kreatif_klinik/logic/cubits/report/report_state.dart';

class ReportCubit extends Cubit<ReportState> {
  final ReportRepository _reportRepository;
  final ExportService _exportService;

  ReportCubit({
    ReportRepository? reportRepository,
    ExportService? exportService,
  })  : _reportRepository = reportRepository ?? ReportRepository(),
        _exportService = exportService ?? ExportService(),
        super(const ReportInitial());

  /// Load report data
  Future<void> loadReport(DateTime startDate, DateTime endDate) async {
    emit(const ReportLoading());

    try {
      final data = await _reportRepository.getReportData(startDate, endDate);
      final orders =
          await _reportRepository.getOrdersByDateRange(startDate, endDate);

      emit(ReportLoaded(data: data, orders: orders));
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// Export report to Excel
  Future<void> exportToExcel() async {
    final currentState = state;
    if (currentState is! ReportLoaded) return;

    emit(const ReportExporting());

    try {
      final filePath = await _exportService.exportOrdersToExcel(
        currentState.orders,
        currentState.data,
      );

      // Share the file
      await _exportService.shareFile(filePath);

      emit(ReportExported(
        filePath: filePath,
        message: 'Laporan berhasil di-export',
      ));

      // Restore previous state
      emit(currentState);
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
      emit(currentState);
    }
  }
  /// Export Sales Detail
  Future<void> exportSalesDetail() async {
    final currentState = state;
    if (currentState is! ReportLoaded) return;

    emit(const ReportExporting());

    try {
      final orders = await _reportRepository.getOrdersWithItemsByDateRange(
        currentState.data.startDate,
        currentState.data.endDate,
      );

      final filePath = await _exportService.exportSalesDetailToExcel(
        orders,
        currentState.data,
      );

      await _exportService.shareFile(filePath);

      emit(ReportExported(
        filePath: filePath,
        message: 'Laporan Penjualan (Detail) berhasil di-export',
      ));

      emit(currentState);
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
      emit(currentState);
    }
  }

  /// Export Purchase Detail
  Future<void> exportPurchaseDetail() async {
    final currentState = state;
    if (currentState is! ReportLoaded) return;

    emit(const ReportExporting());

    try {
      final purchases = await _reportRepository.getPurchasesWithItemsByDateRange(
        currentState.data.startDate,
        currentState.data.endDate,
      );

      final filePath = await _exportService.exportPurchaseDetailToExcel(
        purchases,
        currentState.data,
      );

      await _exportService.shareFile(filePath);

      emit(ReportExported(
        filePath: filePath,
        message: 'Laporan Pembelian (Detail) berhasil di-export',
      ));

      emit(currentState);
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
      emit(currentState);
    }
  }

  /// Export Stock Report
  Future<void> exportStockReport() async {
    final currentState = state;
    // Stock report doesn't necessarily depend on report date range, 
    // but we usually export it from report screen which is loaded.
    
    emit(const ReportExporting());

    try {
      final products = await _reportRepository.getAllProducts();

      final filePath = await _exportService.exportStockReportToExcel(products);

      await _exportService.shareFile(filePath);

      emit(ReportExported(
        filePath: filePath,
        message: 'Laporan Stok berhasil di-export',
      ));

      if (currentState is ReportLoaded) {
        emit(currentState);
      } else {
        // If somehow we allow export without loaded report, go back to initial or whatever
        // But practically we are in ReportLoaded usually.
        // If we were in initial, we might want to stay there or go to loaded if we had data.
        // For safety, let's just reload or keep currentState if it was not exporting.
        // Since we emitted Exporting, we lost previous state if we didn't save it.
        // We saved it in currentState.
        emit(currentState); 
      }
    } catch (e) {
      emit(ReportError(e.toString().replaceAll('Exception: ', '')));
      emit(currentState);
    }
  }
}
