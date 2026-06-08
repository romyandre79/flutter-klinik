import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/models/cart_item.dart';
import 'package:kreatif_klinik/data/models/order_item_batch.dart';
import 'package:kreatif_klinik/data/repositories/product_repository.dart';

class SalesBatchInput {
  final String batchNo;
  final DateTime expiredDate;
  final double availableQty;
  final TextEditingController controller;

  SalesBatchInput({
    required this.batchNo,
    required this.expiredDate,
    required this.availableQty,
    required String quantity,
  }) : controller = TextEditingController(text: quantity);
}

class SelectSalesBatchesDialog extends StatefulWidget {
  final CartItem cartItem;
  final Function(List<OrderItemBatch>) onSave;

  const SelectSalesBatchesDialog({
    super.key,
    required this.cartItem,
    required this.onSave,
  });

  @override
  State<SelectSalesBatchesDialog> createState() => _SelectSalesBatchesDialogState();
}

class _SelectSalesBatchesDialogState extends State<SelectSalesBatchesDialog> {
  List<SalesBatchInput> _batches = [];
  bool _isLoading = true;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadAvailableBatches();
  }

  Future<void> _loadAvailableBatches() async {
    try {
      final productRepo = context.read<ProductRepository>();
      final available = await productRepo.getAvailableBatches(widget.cartItem.product.id!);
      
      if (mounted) {
        setState(() {
          _batches = available.map((row) {
            final batchNo = row['batch_no'] as String;
            final expiredDate = DateTime.parse(row['expired_date'] as String);
            final availableQty = row['available_qty'] as double;

            // Find existing selection in widget.cartItem.batches
            double initialQty = 0;
            for (final selected in widget.cartItem.batches) {
              if (selected.batchNo == batchNo && 
                  selected.expiredDate.year == expiredDate.year &&
                  selected.expiredDate.month == expiredDate.month &&
                  selected.expiredDate.day == expiredDate.day) {
                initialQty = selected.quantity;
                break;
              }
            }

            return SalesBatchInput(
              batchNo: batchNo,
              expiredDate: expiredDate,
              availableQty: availableQty,
              quantity: initialQty > 0 ? initialQty.toStringAsFixed(0) : '',
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data batch: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final b in _batches) {
      b.controller.dispose();
    }
    super.dispose();
  }

  double _getSumOfInputs() {
    double total = 0.0;
    for (final b in _batches) {
      final val = double.tryParse(b.controller.text) ?? 0.0;
      total += val;
    }
    return total;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final sum = _getSumOfInputs();
    
    // Validation:
    // If sum is greater than 0, it MUST match the cart item quantity.
    // If sum is 0, it means the cashier cleared the batch selection (allowed, optional).
    if (sum > 0 && sum != widget.cartItem.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total kuantitas batch ($sum) harus sama dengan jumlah yang dibeli (${widget.cartItem.quantity}).',
          ),
          backgroundColor: AppThemeColors.error,
        ),
      );
      return;
    }

    final List<OrderItemBatch> selectedBatches = [];
    if (sum > 0) {
      for (final b in _batches) {
        final qty = double.tryParse(b.controller.text) ?? 0.0;
        if (qty > 0) {
          selectedBatches.add(OrderItemBatch(
            productId: widget.cartItem.product.id!,
            batchNo: b.batchNo,
            expiredDate: b.expiredDate,
            quantity: qty,
          ));
        }
      }
    }

    widget.onSave(selectedBatches);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final itemUnit = widget.cartItem.selectedUnit?.unitName ?? widget.cartItem.product.unit;
    final double targetQty = widget.cartItem.quantity;
    final double currentSum = _getSumOfInputs();
    final bool isQtyMatched = currentSum == targetQty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Batch Barang',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.cartItem.product.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppThemeColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Summary Indicator Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: currentSum == 0
                    ? Colors.grey.shade50
                    : (isQtyMatched
                        ? Colors.green.shade50
                        : Colors.amber.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: currentSum == 0
                      ? Colors.grey.shade200
                      : (isQtyMatched
                          ? Colors.green.shade200
                          : Colors.amber.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kuantitas di Keranjang',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppThemeColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$targetQty $itemUnit',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Batch Diinput',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppThemeColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$currentSum $itemUnit',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: currentSum == 0
                              ? Colors.grey.shade700
                              : (isQtyMatched
                                  ? Colors.green.shade700
                                  : Colors.amber.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Loading / Error / Content
            Expanded(
              child: _buildBody(),
            ),
            
            const Divider(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Batal',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.cartItem.batches.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onSave([]);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(color: AppThemeColors.error),
                        foregroundColor: AppThemeColors.error,
                      ),
                      child: Text(
                        'Hapus Batch',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading || _error != null ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Simpan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppThemeColors.primary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppThemeColors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: AppThemeColors.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Tidak ada batch tersedia untuk produk ini.',
              style: GoogleFonts.poppins(
                color: AppThemeColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Harap lakukan penerimaan pembelian PO terlebih dahulu.',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView.separated(
        itemCount: _batches.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final batch = _batches[index];
          final formattedExp = DateFormatter.formatDate(batch.expiredDate);
          final unit = widget.cartItem.selectedUnit?.unitName ?? widget.cartItem.product.unit;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // Batch Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            batch.batchNo,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppThemeColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            'Exp: $formattedExp',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppThemeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.analytics_outlined, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            'Tersedia: ${batch.availableQty.toStringAsFixed(0)} $unit',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppThemeColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Qty Input
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: batch.controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Qty Ambil',
                      hintText: '0',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixText: unit,
                      suffixStyle: const TextStyle(fontSize: 11),
                    ),
                    onChanged: (_) {
                      // Trigger state rebuild to update summary indicators
                      setState(() {});
                    },
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return null; // Empty means 0
                      }
                      final qty = double.tryParse(val);
                      if (qty == null) {
                        return 'Harus angka';
                      }
                      if (qty < 0) {
                        return '>= 0';
                      }
                      if (qty > batch.availableQty) {
                        return 'Maks ${batch.availableQty.toStringAsFixed(0)}';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
