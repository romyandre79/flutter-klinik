import 'package:url_launcher/url_launcher.dart';
import 'package:kreatif_otopart/data/models/order.dart';
import 'package:kreatif_otopart/data/repositories/settings_repository.dart';
import 'package:kreatif_otopart/core/utils/currency_formatter.dart';
import 'package:kreatif_otopart/core/utils/date_formatter.dart';
import 'package:kreatif_otopart/core/constants/app_constants.dart';


class WhatsAppService {
  static final WhatsAppService _instance = WhatsAppService._internal();
  factory WhatsAppService() => _instance;
  WhatsAppService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<Map<String, String>> _getStoreInfo() async {
    final settings = await _settingsRepository.getAllSettings();
    return {
      'name': settings[AppConstants.keyStoreName] ?? AppConstants.defaultStoreName,
      'address': settings[AppConstants.keyStoreAddress] ?? AppConstants.defaultStoreAddress,
      'phone': settings[AppConstants.keyStorePhone] ?? AppConstants.defaultStorePhone,
    };
  }

  /// Send order receipt via WhatsApp
  Future<bool> shareOrderReceipt(Order order) async {
    if (order.customerPhone == null || order.customerPhone!.isEmpty) {
      throw Exception('Nomor HP pelanggan tidak tersedia');
    }

    final storeInfo = await _getStoreInfo();
    final message = _buildReceiptMessage(order, storeInfo);
    final phoneNumber = order.whatsappNumber;

    if (phoneNumber.isEmpty) {
      throw Exception('Format nomor HP tidak valid');
    }

    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        throw Exception('Tidak dapat membuka WhatsApp');
      }
    } catch (e) {
      throw Exception('Gagal membuka WhatsApp: ${e.toString()}');
    }
  }

  /// Send order notification to customer
  Future<bool> sendOrderNotification(Order order, String notificationType) async {
    if (order.customerPhone == null || order.customerPhone!.isEmpty) {
      throw Exception('Nomor HP pelanggan tidak tersedia');
    }

    final storeInfo = await _getStoreInfo();
    final message = _buildNotificationMessage(order, notificationType, storeInfo);
    final phoneNumber = order.whatsappNumber;

    if (phoneNumber.isEmpty) {
      throw Exception('Format nomor HP tidak valid');
    }

    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        throw Exception('Tidak dapat membuka WhatsApp');
      }
    } catch (e) {
      throw Exception('Gagal membuka WhatsApp: ${e.toString()}');
    }
  }

  String _buildReceiptMessage(Order order, Map<String, String> storeInfo) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('*${storeInfo['name']}*');
    buffer.writeln(storeInfo['address']);
    buffer.writeln('Telp: ${storeInfo['phone']}');
    buffer.writeln('================================');
    buffer.writeln();

    // Invoice info
    buffer.writeln('*STRUK ORDER*');
    buffer.writeln('No: ${order.invoiceNumber}');
    buffer.writeln('Tgl: ${DateFormatter.formatDateTime(order.createdAt ?? DateTime.now())}');
    buffer.writeln('Pelanggan: ${order.customerName}');
    buffer.writeln('Status: ${order.status.displayName}');
    buffer.writeln();

    // Items
    buffer.writeln('*Detail Order:*');
    buffer.writeln('--------------------------------');
    for (final item in order.items ?? []) {
      buffer.writeln('• ${item.serviceName}');
      buffer.writeln('  ${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.pricePerUnit)}');
      buffer.writeln('  = ${CurrencyFormatter.format(item.subtotal)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln();

    // Total
    buffer.writeln('*TOTAL: ${CurrencyFormatter.format(order.totalAmount)}*');

    // Payment info
    if (order.paidAmount > 0) {
      buffer.writeln('Dibayar: ${CurrencyFormatter.format(order.paidAmount)}');
      final remaining = order.remainingPayment;
      if (remaining > 0) {
        buffer.writeln('*Sisa: ${CurrencyFormatter.format(remaining)}*');
      } else {
        buffer.writeln('✅ LUNAS');
      }
    } else {
      buffer.writeln('Belum ada pembayaran');
    }

    buffer.writeln();

    // Due date
    if (order.dueDate != null) {
      buffer.writeln('📅 Ambil: ${DateFormatter.formatDate(order.dueDate!)}');
    }

    // Notes
    if (order.notes != null && order.notes!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Catatan: ${order.notes}');
    }

    buffer.writeln();
    buffer.writeln('================================');
    buffer.writeln('Terima kasih atas kepercayaan Anda!');

    return buffer.toString();
  }

  String _buildNotificationMessage(Order order, String notificationType, Map<String, String> storeInfo) {
    final buffer = StringBuffer();

    buffer.writeln('Halo ${order.customerName},');
    buffer.writeln();

    switch (notificationType) {
      case 'ready':
        buffer.writeln('🎉 *Pesanan Anda sudah siap diambil!*');
        buffer.writeln();
        buffer.writeln('No. Order: ${order.invoiceNumber}');
        buffer.writeln();
        buffer.writeln('Silakan ambil pesanan Anda di:');
        buffer.writeln('📍 ${storeInfo['address']}');
        if (order.remainingPayment > 0) {
          buffer.writeln();
          buffer.writeln('*Sisa pembayaran: ${CurrencyFormatter.format(order.remainingPayment)}*');
        }
        break;

      case 'process':
        buffer.writeln('⏳ *Pesanan Anda sedang diproses*');
        buffer.writeln();
        buffer.writeln('No. Order: ${order.invoiceNumber}');
        if (order.dueDate != null) {
          buffer.writeln('Estimasi selesai: ${DateFormatter.formatDate(order.dueDate!)}');
        }
        break;

      case 'done':
        buffer.writeln('✅ *Terima kasih!*');
        buffer.writeln();
        buffer.writeln('Penjualan ${order.invoiceNumber} telah selesai.');
        buffer.writeln('Terima kasih telah berbelanja di tempat kami.');
        buffer.writeln();
        buffer.writeln('Sampai jumpa di kunjungan berikutnya! 🙏');
        break;

      default:
        buffer.writeln('No. Order: ${order.invoiceNumber}');
        buffer.writeln('Status: ${order.status.displayName}');
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('${storeInfo['name']}');
    buffer.writeln('Telp: ${storeInfo['phone']}');

    return buffer.toString();
  }
}
