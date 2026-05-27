import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/core/utils/currency_formatter.dart';
import 'package:kreatif_otopart/core/utils/date_formatter.dart';
import 'package:kreatif_otopart/data/models/purchase_order.dart';
import 'package:kreatif_otopart/data/models/purchase_order_item.dart';
import 'package:kreatif_otopart/data/models/supplier.dart';
import 'package:kreatif_otopart/logic/cubits/purchase_order/purchase_order_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/purchase_order/purchase_order_state.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_state.dart';
import 'package:kreatif_otopart/data/models/product.dart';
import 'package:kreatif_otopart/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/product/product_state.dart';
import 'package:kreatif_otopart/presentation/screens/purchasing/purchase_order_detail_screen.dart';
import 'package:kreatif_otopart/data/models/unit.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_state.dart';
import 'package:kreatif_otopart/presentation/widgets/searchable_supplier_picker.dart';
import 'package:kreatif_otopart/presentation/widgets/searchable_unit_picker.dart';

class PurchaseOrderCreateScreen extends StatefulWidget {
  const PurchaseOrderCreateScreen({super.key});

  @override
  State<PurchaseOrderCreateScreen> createState() => _PurchaseOrderCreateScreenState();
}

class _PurchaseOrderCreateScreenState extends State<PurchaseOrderCreateScreen> {
  Supplier? _selectedSupplier;
  final List<PurchaseOrderItem> _items = [];
  final TextEditingController _notesController = TextEditingController();
  DateTime _expectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Load suppliers and products
    context.read<SupplierCubit>().loadSuppliers();
    context.read<ProductCubit>().loadProducts();
  }

  void _addItem() async {
    final productState = context.read<ProductCubit>().state;
    List<Product> products = [];
    if (productState is ProductLoaded) {
      products = productState.products;
    }
    
    // Capture UnitCubit from current context to pass to the new route
    final unitCubit = context.read<UnitCubit>();

    final PurchaseOrderItem? newItem = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: unitCubit,
          child: PurchaseOrderItemEditor(
            products: products,
          ),
        ),
      ),
    );

    if (newItem != null) {
      setState(() {
        _items.add(newItem);
      });
    }
  }

  void _editItem(int index) async {
    final productState = context.read<ProductCubit>().state;
    List<Product> products = [];
    if (productState is ProductLoaded) {
      products = productState.products;
    }

    final unitCubit = context.read<UnitCubit>();

    final PurchaseOrderItem? updatedItem = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: unitCubit,
          child: PurchaseOrderItemEditor(
            products: products,
            existingItem: _items[index],
          ),
        ),
      ),
    );

    if (updatedItem != null) {
      setState(() {
        _items[index] = updatedItem;
      });
    }
  }

  void _submit() {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Supplier ...')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item belum ditambahkan')),
      );
      return;
    }

    final totalAmount = _items.fold(0, (sum, item) => sum + item.subtotal);

    final po = PurchaseOrder(
      supplierId: _selectedSupplier!.id!,
      supplier: _selectedSupplier, // Populate supplier object here
      orderDate: DateTime.now(),
      expectedDate: _expectedDate,
      status: 'pending',
      totalAmount: totalAmount,
      notes: _notesController.text,
      items: _items,
    );

    context.read<PurchaseOrderCubit>().createPurchaseOrder(po);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembelian Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              bool isSupplierSelected = _selectedSupplier != null;
               if (!isSupplierSelected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a supplier first')),
                  );
                  return;
              }
              _addItem();
            },
          ),
        ],
      ),
      body: BlocListener<PurchaseOrderCubit, PurchaseOrderState>(
        listener: (context, state) {
          if (state is PoOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
            if (state.purchaseOrder != null) {
              // Replace current screen with Detail Screen
              final poCubit = context.read<PurchaseOrderCubit>();
               Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: poCubit,
                    child: PurchaseOrderDetailScreen(order: state.purchaseOrder!),
                  ),
                ),
              );
            } else {
              Navigator.pop(context);
            }
          } else if (state is PoError) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        child: Column(
          children: [
            // Header Form
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: Colors.white,
              child: Column(
                children: [
                   // Supplier Picker
                   SearchableSupplierPicker(
                     selectedSupplier: _selectedSupplier,
                     onSupplierSelected: (val) => setState(() => _selectedSupplier = val),
                   ),
                   const SizedBox(height: AppSpacing.sm),
                   // Tgl Kedatangan
                   ListTile(
                     title: const Text('Tgl Kedatangan'),
                     subtitle: Text(DateFormatter.formatDate(_expectedDate)),
                     trailing: const Icon(Icons.calendar_today),
                     contentPadding: EdgeInsets.zero,
                     onTap: () async {
                       final date = await showDatePicker(
                         context: context,
                         initialDate: _expectedDate,
                         firstDate: DateTime.now(),
                         lastDate: DateTime.now().add(const Duration(days: 365)),
                       );
                       if (date != null) setState(() => _expectedDate = date);
                     },
                   ),
                ],
              ),
            ),
            const Divider(),
            
            // Items List
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Tidak ada Item'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item.itemName),
                          subtitle: Text('${item.quantity} ${item.unit} x ${CurrencyFormatter.format(item.cost)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CurrencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editItem(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => setState(() => _items.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(_items.fold(0, (sum, i) => sum + i.subtotal)),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppThemeColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class PurchaseOrderItemEditor extends StatefulWidget {
  final PurchaseOrderItem? existingItem;
  final List<Product> products;

  const PurchaseOrderItemEditor({
    super.key,
    this.existingItem, 
    required this.products,
  });

  @override
  State<PurchaseOrderItemEditor> createState() => _PurchaseOrderItemEditorState();
}

class _PurchaseOrderItemEditorState extends State<PurchaseOrderItemEditor> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _searchController = TextEditingController(); // For searching products
  
  Product? _selectedProduct;
  List<Product> _filteredProducts = [];
  bool _showSearchResults = false;
  String _selectedUnit = 'pcs';

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _nameController.text = widget.existingItem!.itemName;
      _qtyController.text = widget.existingItem!.quantity.toString();
      _costController.text = widget.existingItem!.cost.toString();
      _selectedUnit = widget.existingItem!.unit;
      
      // Try to find product by ID or Name if available
      if (widget.existingItem!.productId != null) {
        try {
          _selectedProduct = widget.products.firstWhere((p) => p.id == widget.existingItem!.productId);
          _searchController.text = _selectedProduct!.name;
        } catch (_) {}
      } else {
        // If no product ID but we have a name, maybe pre-fill search?
        _searchController.text = widget.existingItem!.itemName;
      }
    }

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = widget.products
          .where((p) => p.type == ProductType.goods && 
              (p.name.toLowerCase().contains(query) || 
               (p.barcode != null && p.barcode!.toLowerCase().contains(query))))
          .take(5) // Limit results
          .toList();
      
      // Show results if query is not empty and we haven't selected a product (or user is typing something new)
      _showSearchResults = query.isNotEmpty && (_selectedProduct == null || _selectedProduct!.name.toLowerCase() != query);
      
      // Loop back: Sync name controller with search text if no product selected
      if (_selectedProduct == null || _selectedProduct!.name != _searchController.text) {
         _nameController.text = _searchController.text;
         if (_selectedProduct != null && _selectedProduct!.name != _searchController.text) {
           _selectedProduct = null;
         }
      }
    });
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _searchController.text = product.name;
      _nameController.text = product.name;
      _costController.text = product.cost.toString();
      _selectedUnit = product.unit;
      _showSearchResults = false; 
    });
  }

  void _submit() {
    // If name is empty, try to use search controller text
    if (_nameController.text.isEmpty && _searchController.text.isNotEmpty) {
      _nameController.text = _searchController.text;
    }

    if (_nameController.text.isEmpty || _qtyController.text.isEmpty || _costController.text.isEmpty) return;
    
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final cost = int.tryParse(_costController.text) ?? 0;
    
    if (qty <= 0) return;

    final item = PurchaseOrderItem(
      id: widget.existingItem?.id,
      itemName: _nameController.text,
      quantity: qty,
      unit: _selectedUnit,
      cost: cost,
      subtotal: qty * cost,
      productId: _selectedProduct?.id ?? widget.existingItem?.productId,
    );
    
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem != null ? 'Ubah Item' : 'Tambah Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search / Name Field
              Text('Nama Item / Cari Produk', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ketik nama item...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                           setState(() {
                             _selectedProduct = null;
                             _searchController.clear();
                             _nameController.clear();
                             _showSearchResults = false;
                           });
                        }
                      )
                    : const Icon(Icons.search),
                ),
              ),
              
              // Inline Search Results
              if (_showSearchResults && _filteredProducts.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return ListTile(
                        dense: true,
                        title: Text(product.name),
                        subtitle: Text('${CurrencyFormatter.format(product.cost)} | Stok: ${product.stock ?? 0}'),
                        onTap: () => _selectProduct(product),
                      );
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.md),
              
              TextField(
                controller: _qtyController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              
              // Unit Selection
              SearchableUnitPicker(
                label: 'Satuan',
                selectedUnit: _selectedUnit,
                manualUnits: _selectedProduct != null 
                    ? _selectedProduct!.units.map((u) => u.unitName).toList()
                    : [_selectedUnit],
                onUnitSelected: (val) => setState(() => _selectedUnit = val),
              ),
              const SizedBox(height: AppSpacing.md),

              TextField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Harga Beli (Satuan)',
                  border: OutlineInputBorder(),
                  filled: true,
                  prefixText: 'Rp ',
                  helperText: 'Harga beli terakhir / dari Master Item',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(widget.existingItem != null ? 'Update' : 'Tambah Data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
