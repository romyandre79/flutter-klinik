import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kreatif_klinik/core/theme/app_theme.dart';
import 'package:kreatif_klinik/core/utils/date_formatter.dart';
import 'package:kreatif_klinik/data/models/product.dart';
import 'package:kreatif_klinik/data/models/stock_transfer.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/product/product_state.dart';
import 'package:kreatif_klinik/logic/cubits/stock_transfer/stock_transfer_cubit.dart';
import 'package:kreatif_klinik/logic/cubits/stock_transfer/stock_transfer_state.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StockTransferCubit>().loadTransfers();
    context.read<ProductCubit>().loadProducts();
  }

  void _showTransferDialog() {
    final qtyController = TextEditingController(text: '1');
    final multiplierController = TextEditingController(text: '12');
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    Product? sourceProduct;
    Product? targetProduct;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final productState = context.read<ProductCubit>().state;
          List<Product> products = [];
          if (productState is ProductLoaded) {
            products = productState.products.where((p) => p.type == ProductType.goods).toList();
          }

          double sourceQty = double.tryParse(qtyController.text) ?? 0;
          double multiplier = double.tryParse(multiplierController.text) ?? 0;
          double targetResult = sourceQty * multiplier;

          return AlertDialog(
            title: const Text('Transfer Stok / Konversi'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Source Product
                    DropdownButtonFormField<Product>(
                      value: sourceProduct,
                      decoration: const InputDecoration(labelText: 'Dari Produk (Sumber)'),
                      items: products.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (${p.unit}) - Stok: ${p.stock ?? 0}'),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => sourceProduct = val),
                      validator: (v) => v == null ? 'Pilih produk sumber' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Target Product
                    DropdownButtonFormField<Product>(
                      value: targetProduct,
                      decoration: const InputDecoration(labelText: 'Ke Produk (Tujuan)'),
                      items: products.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (${p.unit})'),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => targetProduct = val),
                      validator: (v) {
                        if (v == null) return 'Pilih produk tujuan';
                        if (v.id == sourceProduct?.id) return 'Produk tujuan tidak boleh sama';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyController,
                            decoration: const InputDecoration(labelText: 'Qty Sumber'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setDialogState(() {}),
                            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Minimal 1' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: multiplierController,
                            decoration: const InputDecoration(labelText: 'Multiplier'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setDialogState(() {}),
                            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Minimal 1' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hasil: $targetResult ${targetProduct?.unit ?? ""}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Catatan (Opsional)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    if ((sourceProduct!.stock ?? 0) < sourceQty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stok sumber tidak mencukupi')),
                      );
                      return;
                    }

                    final transfer = StockTransfer(
                      sourceProductId: sourceProduct!.id!,
                      targetProductId: targetProduct!.id!,
                      sourceQty: sourceQty,
                      targetQty: targetResult,
                      multiplier: multiplier,
                      notes: notesController.text,
                    );

                    context.read<StockTransferCubit>().createTransfer(transfer);
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Konversi Sekarang'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockTransferCubit, StockTransferState>(
      listener: (context, state) {
        if (state is StockTransferActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
          context.read<ProductCubit>().loadProducts(); // Refresh stocks
        } else if (state is StockTransferError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfer Stok / Konversi'),
        ),
        body: BlocBuilder<StockTransferCubit, StockTransferState>(
          builder: (context, state) {
            if (state is StockTransferLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is StockTransferLoaded) {
              final transfers = state.transfers;
              if (transfers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swap_horiz, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Belum ada riwayat transfer', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showTransferDialog,
                        child: const Text('Mulai Transfer Pertama'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: transfers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final st = transfers[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormatter.formatDateTime(st.createdAt!),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Berhasil',
                                  style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DARI', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Text(st.sourceProductName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${st.sourceQty} Unit', style: const TextStyle(color: Colors.red, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('KE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Text(st.targetProductName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${st.targetQty} Unit', style: const TextStyle(color: Colors.green, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (st.notes != null && st.notes!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Text(
                              st.notes!,
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showTransferDialog,
          backgroundColor: AppThemeColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
