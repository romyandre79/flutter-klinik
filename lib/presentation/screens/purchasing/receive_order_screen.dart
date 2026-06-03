import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/models/purchase_order.dart';
import 'package:kreatif_klinik/data/models/purchase_order_item_batch.dart';
import 'package:kreatif_klinik/logic/cubits/purchase_order/purchase_order_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/purchase_order/purchase_order_state.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_cubit.dart';

class BatchInput {
  final TextEditingController batchNoController;
  final TextEditingController qtyController;
  DateTime? expiredDate;

  BatchInput({
    String batchNo = '',
    String qty = '',
    this.expiredDate,
  })  : batchNoController = TextEditingController(text: batchNo),
        qtyController = TextEditingController(text: qty);
}

class ReceiveOrderScreen extends StatefulWidget {
  final PurchaseOrder order;

  const ReceiveOrderScreen({super.key, required this.order});

  @override
  State<ReceiveOrderScreen> createState() => _ReceiveOrderScreenState();
}

class _ReceiveOrderScreenState extends State<ReceiveOrderScreen> {
  final Map<int, List<BatchInput>> _itemBatches = {};
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Initialize one batch entry for each item, prefilled with the ordered quantity
    for (int i = 0; i < widget.order.items.length; i++) {
      final item = widget.order.items[i];
      final keyId = item.id ?? i;
      _itemBatches[keyId] = [
        BatchInput(
          qty: item.quantity.toString(),
          expiredDate: DateTime.now().add(const Duration(days: 365)), // Default 1 year expiry
        )
      ];
    }
  }

  @override
  void dispose() {
    for (final list in _itemBatches.values) {
      for (final input in list) {
        input.batchNoController.dispose();
        input.qtyController.dispose();
      }
    }
    super.dispose();
  }

  void _addBatchRow(int itemId) {
    setState(() {
      _itemBatches[itemId]!.add(BatchInput(
        expiredDate: DateTime.now().add(const Duration(days: 365)),
      ));
    });
  }

  void _removeBatchRow(int itemId, int index) {
    setState(() {
      if (_itemBatches[itemId]!.length > 1) {
        final removed = _itemBatches[itemId]!.removeAt(index);
        removed.batchNoController.dispose();
        removed.qtyController.dispose();
      }
    });
  }

  Future<void> _selectExpiryDate(BuildContext context, BatchInput input) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: input.expiredDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // up to 10 years
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppThemeColors.primary,
              onPrimary: Colors.white,
              onSurface: AppThemeColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        input.expiredDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional manual validation for expiry dates and empty inputs
    final List<PurchaseOrderItemBatch> batches = [];
    
    for (int i = 0; i < widget.order.items.length; i++) {
      final item = widget.order.items[i];
      final keyId = item.id ?? i;
      final inputs = _itemBatches[keyId]!;
      double itemBatchTotalQty = 0.0;

      for (final input in inputs) {
        final batchNo = input.batchNoController.text.trim();
        final qtyStr = input.qtyController.text.trim();
        final qty = double.tryParse(qtyStr) ?? 0.0;

        if (batchNo.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nomor batch untuk "${item.itemName}" tidak boleh kosong.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (input.expiredDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tanggal kedaluwarsa untuk "${item.itemName}" belum dipilih.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (qty <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jumlah untuk "${item.itemName}" harus lebih dari 0.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (item.id == null || item.productId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kesalahan data item pembelian.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        itemBatchTotalQty += qty;

        batches.add(PurchaseOrderItemBatch(
          purchaseOrderItemId: item.id!,
          productId: item.productId!,
          batchNo: batchNo,
          expiredDate: input.expiredDate!,
          quantity: qty,
        ));
      }

      if (itemBatchTotalQty != item.quantity.toDouble()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total kuantitas batch untuk "${item.itemName}" (${itemBatchTotalQty.toStringAsFixed(0)} ${item.unit}) harus sama dengan kuantitas yang dipesan (${item.quantity} ${item.unit}).',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Submit via cubit
    context.read<PurchaseOrderCubit>().receivePurchaseOrder(widget.order.id!, batches);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Input Batch Terima Barang'),
      ),
      body: BlocListener<PurchaseOrderCubit, PurchaseOrderState>(
        listener: (context, state) {
          if (state is PoOperationSuccess) {
            // Trigger products reload to update UI
            context.read<ProductCubit>().loadProducts();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // Pop the current screen (ReceiveOrderScreen)
            Navigator.pop(context);
          } else if (state is PoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Info Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppThemeColors.primary.withValues(alpha: 0.05),
                child: Text(
                  'Masukkan no batch & tgl kedaluwarsa untuk tiap item. Jika item terdiri dari beberapa batch yang berbeda, silakan klik tombol "+ Tambah Batch".',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppThemeColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.order.items.length,
                  itemBuilder: (context, i) {
                    final item = widget.order.items[i];
                    final keyId = item.id ?? i;
                    final batches = _itemBatches[keyId] ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.itemName,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Dipesan: ${item.quantity} ${item.unit}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            
                            // Batches List
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: batches.length,
                              separatorBuilder: (_, index) => const SizedBox(height: 12),
                              itemBuilder: (context, bIdx) {
                                final batchInput = batches[bIdx];
                                final formattedDate = batchInput.expiredDate != null
                                    ? DateFormatter.formatDate(batchInput.expiredDate!)
                                    : 'Pilih Tanggal';

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Number Circle
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14.0, right: 8.0),
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: AppThemeColors.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          '${bIdx + 1}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppThemeColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Batch No Input
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: batchInput.batchNoController,
                                        decoration: const InputDecoration(
                                          labelText: 'No. Batch',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Wajib diisi';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Expiry Date Input
                                    Expanded(
                                      flex: 3,
                                      child: InkWell(
                                        onTap: () => _selectExpiryDate(context, batchInput),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade400),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  formattedDate,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    color: batchInput.expiredDate != null
                                                        ? Colors.black87
                                                        : Colors.grey.shade500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Qty Input
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: batchInput.qtyController,
                                        decoration: InputDecoration(
                                          labelText: 'Qty',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          border: const OutlineInputBorder(),
                                          suffixText: item.unit,
                                          suffixStyle: const TextStyle(fontSize: 11),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Wajib';
                                          }
                                          final qty = double.tryParse(val) ?? 0.0;
                                          if (qty <= 0) {
                                            return '> 0';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    
                                    // Remove Row Button
                                    if (batches.length > 1)
                                      IconButton(
                                        padding: const EdgeInsets.only(top: 8),
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _removeBatchRow(keyId, bIdx),
                                      ),
                                  ],
                                );
                              },
                            ),
                            
                            // Add Batch Row Button
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: TextButton.icon(
                                onPressed: () => _addBatchRow(keyId),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah Batch'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppThemeColors.primary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.grey),
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
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Terima Barang',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
