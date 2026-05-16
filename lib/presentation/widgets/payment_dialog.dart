import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/currency_formatter.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart'; // Import DateFormatter
import 'package:kreatif_klinik/core/utils/thousand_separator_formatter.dart';
import 'package:kreatif_klinik/data/models/order.dart';
import 'package:kreatif_klinik/data/models/payment.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentDialog extends StatefulWidget {
  final int totalAmount;
  final Function(int paidAmount, PaymentMethod paymentMethod, OrderStatus status, DateTime? dueDate) onConfirm; // Update signature

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late TextEditingController _paymentController;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  OrderStatus _orderStatus = OrderStatus.process;
  DateTime _dueDate = DateTime.now(); // Default to now
  int _change = 0;

  @override
  void initState() {
    super.initState();
    _paymentController = TextEditingController(
      text: CurrencyFormatter.format(widget.totalAmount).replaceAll('Rp ', '').replaceAll('.', ''),
    );
    _calculateChange();
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final paid = ThousandSeparatorFormatter.parseToInt(_paymentController.text);
    setState(() {
      _change = paid > widget.totalAmount ? paid - widget.totalAmount : 0;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
         return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppThemeColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day, DateTime.now().hour, DateTime.now().minute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.payment, color: AppThemeColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            'Pembayaran',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Tagihan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppThemeColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(widget.totalAmount),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppThemeColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Due Date Selection
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppThemeColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppThemeColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Ambil: ${DateFormatter.formatDate(_dueDate)}',
                            style: GoogleFonts.poppins(
                              color: AppThemeColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Input
            TextFormField(
              controller: _paymentController,
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandSeparatorFormatter(),
              ],
              onChanged: (value) => _calculateChange(),
            ),
            const SizedBox(height: 16),

            // Payment Method Dropdown
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Metode Pembayaran',
                border: OutlineInputBorder(),
              ),
              items: PaymentMethod.values.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paymentMethod = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Order Status Dropdown
            DropdownButtonFormField<OrderStatus>(
              initialValue: _orderStatus,
              decoration: const InputDecoration(
                labelText: 'Status Penjualan',
                border: OutlineInputBorder(),
              ),
              items: OrderStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _orderStatus = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Change Display
            if (_change > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppThemeColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppThemeColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kembalian',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.success,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(_change),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(color: AppThemeColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final paid = ThousandSeparatorFormatter.parseToInt(_paymentController.text);
            
            // Validate Selesai status
            if (_orderStatus == OrderStatus.done && paid < widget.totalAmount) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pesanan harus lunas jika status Selesai'),
                  backgroundColor: AppThemeColors.error,
                ),
              );
              return;
            }

            widget.onConfirm(paid, _paymentMethod, _orderStatus, _dueDate);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Bayar',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
