import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/core/utils/currency_formatter.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/data/models/product_unit.dart';
import 'package:kreatif_otopart/data/repositories/product_repository.dart';
import 'package:kreatif_otopart/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/product/product_state.dart';


class UnitConversionScreen extends StatefulWidget {
  const UnitConversionScreen({super.key});

  @override
  State<UnitConversionScreen> createState() => _UnitConversionScreenState();
}

class _UnitConversionScreenState extends State<UnitConversionScreen> {
  Product? _selectedProduct;
  ProductUnit? _fromUnit;
  ProductUnit? _toUnit;
  final _qtyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _onProductSelected(Product? product) {
    setState(() {
      _selectedProduct = product;
      _fromUnit = product?.units.isNotEmpty == true ? product!.units.first : null;
      _toUnit = product?.units.length == 2 ? product!.units[1] : null;
    });
  }

  Future<void> _convert() async {
    if (_selectedProduct == null || _fromUnit == null || _toUnit == null) return;
    
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah tidak valid'), backgroundColor: AppThemeColors.error),
      );
      return;
    }

    if (_fromUnit!.stock < qty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok asal tidak mencukupi'), backgroundColor: AppThemeColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Logic: if fromUnit -> toUnit, we need to know the multiplier.
      // In our model, multiplier is how many of THIS unit are in 1 PARENT unit.
      // So if 'Box' is parent of 'Strip' with multiplier 10: 
      // 1 Box = 10 Strips. 
      // If converting from Box to Strip, multiplier is 10.
      
      double effectiveMultiplier = 1.0;
      if (_toUnit!.parentUnitId == _fromUnit!.id) {
        // From Parent to Child (e.g. BOX to PCS, if PCS points to BOX)
        effectiveMultiplier = _toUnit!.multiplier;
      } else if (_fromUnit!.parentUnitId == _toUnit!.id) {
        // From Child to Parent (e.g. PACK to PCS, if PACK points to PCS)
        effectiveMultiplier = _fromUnit!.multiplier;
      } else if (_fromUnit!.parentUnitId != null && _fromUnit!.parentUnitId == _toUnit!.parentUnitId) {
        // Siblings (e.g. PACK to BOX, both pointing to PCS)
        effectiveMultiplier = _fromUnit!.multiplier / _toUnit!.multiplier;
      } else {
        // Complex conversion not supported in this simple UI for now
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konversi hanya didukung antar tingkat yang berhubungan langsung'), backgroundColor: AppThemeColors.error),
        );
        setState(() => _isLoading = false);
        return;
      }

      await context.read<ProductRepository>().convertUnit(
        productId: _selectedProduct!.id!,
        fromUnitId: _fromUnit!.id!,
        toUnitId: _toUnit!.id!,
        fromQty: qty,
        multiplier: effectiveMultiplier,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konversi berhasil'), backgroundColor: AppThemeColors.success),
        );
        Navigator.pop(context);
        context.read<ProductCubit>().loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppThemeColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konversi Satuan Stok', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppThemeColors.headerGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocListener<ProductCubit, ProductState>(
        listener: (context, state) {
          if (state is ProductLoaded && _selectedProduct != null) {
            try {
              // Refresh _selectedProduct and its units from the new state
              final updatedProduct = state.products.firstWhere((p) => p.id == _selectedProduct!.id);
              setState(() {
                _selectedProduct = updatedProduct;
                if (_fromUnit != null) {
                  _fromUnit = updatedProduct.units.firstWhere((u) => u.unitName == _fromUnit!.unitName);
                }
                if (_toUnit != null) {
                  _toUnit = updatedProduct.units.firstWhere((u) => u.unitName == _toUnit!.unitName);
                }
              });
            } catch (_) {
              // Product no longer exists, clear selection
              setState(() {
                _selectedProduct = null;
                _fromUnit = null;
                _toUnit = null;
              });
            }
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Barang', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              _buildProductSelector(),
              if (_selectedProduct != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildConversionForm(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selectedProduct == null ? null : Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _convert,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            backgroundColor: AppThemeColors.primary,
          ),
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Text('Proses Konversi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return BlocBuilder<ProductCubit, ProductState>(
      builder: (context, state) {
        if (state is ProductLoading) return const CircularProgressIndicator();
        if (state is ProductLoaded) {
          final goods = state.products.where((p) => p.isGoods).toList();
          return DropdownButtonFormField<int>(
            value: _selectedProduct?.id,
            items: goods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
            onChanged: (id) {
              final product = goods.firstWhere((p) => p.id == id);
              _onProductSelected(product);
            },
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
              prefixIcon: const Icon(Icons.inventory_2),
            ),
          );
        }
        return const Text('Gagal memuat barang');
      },
    );
  }

  Widget _buildConversionForm() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
        side: BorderSide(color: AppThemeColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _fromUnit?.id,
                    items: _selectedProduct!.units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.unitName))).toList(),
                    onChanged: (val) => setState(() => _fromUnit = _selectedProduct!.units.firstWhere((u) => u.id == val)),
                    decoration: const InputDecoration(labelText: 'Dari Satuan'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward, color: AppThemeColors.primary),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _toUnit?.id,
                    items: _selectedProduct!.units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.unitName))).toList(),
                    onChanged: (val) => setState(() => _toUnit = _selectedProduct!.units.firstWhere((u) => u.id == val)),
                    decoration: const InputDecoration(labelText: 'Ke Satuan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah yang dikonversi',
                helperText: _fromUnit != null ? 'Sisa Stok: ${_fromUnit!.stock} ${_fromUnit!.unitName}' : null,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_fromUnit != null && _toUnit != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildMultiplierInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierInfo() {
    String text = '';
    if (_fromUnit!.parentUnitId == _toUnit!.id) {
       text = '1 ${_fromUnit!.unitName} = ${_fromUnit!.multiplier} ${_toUnit!.unitName}';
    } else if (_toUnit!.parentUnitId == _fromUnit!.id) {
       text = '1 ${_fromUnit!.unitName} = ${1 / _toUnit!.multiplier} ${_toUnit!.unitName}';
    } else {
       text = 'Hubungan satuan tidak langsung';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppThemeColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppThemeColors.primary)),
        ],
      ),
    );
  }
}
