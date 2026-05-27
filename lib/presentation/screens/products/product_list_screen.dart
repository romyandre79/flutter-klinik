import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/core/utils/currency_formatter.dart';
import 'package:kreatif_pos/data/models/product.dart';
import 'package:kreatif_pos/logic/cubits/product/product_cubit.dart';
import 'package:kreatif_pos/logic/cubits/product/product_state.dart';
import 'package:kreatif_pos/presentation/screens/products/product_form_screen.dart';
import 'package:kreatif_pos/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_pos/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_pos/data/models/user.dart';
import 'package:kreatif_pos/logic/cubits/unit/unit_cubit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kreatif_pos/core/services/export_service.dart';
import 'package:kreatif_pos/data/repositories/unit_repository.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ProductCubit>().loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
        ),
        title: Text(
          'Hapus Item',
          style: AppTypography.titleLarge,
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${product.name}"?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: AppTypography.labelMedium.copyWith(
                color: AppThemeColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ProductCubit>().deleteProduct(product.id!);
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.smRadius,
              ),
            ),
            child: Text(
              'Hapus',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToForm({Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: context.read<ProductCubit>(),
            ),
            BlocProvider(
              create: (context) => UnitCubit(UnitRepository())..loadUnits(),
            ),
          ],
          child: ProductFormScreen(product: product),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Nama atau Barcode...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdRadius,
                  borderSide: BorderSide(color: AppThemeColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                // Debounce could be added here if needed, for now just direct search
                context.read<ProductCubit>().loadProducts(query: value);
              },
            ),
          ),
          
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppThemeColors.primary,
              unselectedLabelColor: AppThemeColors.textSecondary,
              indicatorColor: AppThemeColors.primary,
              tabs: const [
                Tab(text: 'Semua'),
                Tab(text: 'Jasa/Layanan'),
                Tab(text: 'Barang'),
              ],
            ),
          ),

          // Content
          Expanded(
            child: BlocConsumer<ProductCubit, ProductState>(
              listener: (context, state) {
                if (state is ProductOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppThemeColors.success,
                    ),
                  );
                } else if (state is ProductError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppThemeColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is ProductLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppThemeColors.primary,
                    ),
                  );
                }

                if (state is ProductLoaded) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(state.products),
                      _buildList(state.serviceList),
                      _buildList(state.goodsList),
                    ],
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildList(List<Product> products) {
    if (products.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: () => context.read<ProductCubit>().loadProducts(),
      color: AppThemeColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (!mounted) return;
        context.read<ProductCubit>().importProductsFromFile(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih file: $e'),
          backgroundColor: AppThemeColors.error,
        ),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    // Implement template download logic via ExportService or just create a simple file
    // For now, we can create a simple Excel file with headers
    final excel = Excel.createExcel();
    final sheet = excel['Template Produk'];
    
    // Headers
    // Name, Description, Price, Cost, Stock, Unit, Type (Barang/Jasa), Barcode
    List<String> headers = ['Nama Produk', 'Deskripsi', 'Harga Jual', 'Harga Beli', 'Stok', 'Satuan', 'Tipe (Barang/Jasa)', 'Barcode'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    // Example Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('Contoh Produk');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('Deskripsi produk');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = IntCellValue(10000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = IntCellValue(5000);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = IntCellValue(100);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = TextCellValue('pcs');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 1)).value = TextCellValue('Barang');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1)).value = TextCellValue('123456789');

    excel.delete('Sheet1');

    final fileName = 'Template_Import_Produk.xlsx';
    final filePath = await ExportService().saveExcelFile(excel, fileName);

    if (filePath != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template disimpan di: $fileName'),
          backgroundColor: AppThemeColors.success,
          action: SnackBarAction(
            label: 'Buka',
            textColor: Colors.white,
            onPressed: () {
               SharePlus.instance.share(ShareParams(files: [XFile(filePath)], text: 'Template Import Produk'));
            },
          ),
        ),
      );
    }
  }

  Widget _buildHeader() {
    final authState = context.read<AuthCubit>().state;
    final isOwner = authState is AuthAuthenticated && authState.user.role == UserRole.owner;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppThemeColors.headerGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Title
              Expanded(
                child: Text(
                  'Master Item',
                  style: AppTypography.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'import') {
                      _pickAndImportFile();
                    } else if (value == 'template') {
                      _downloadTemplate();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file, color: AppThemeColors.primary),
                          SizedBox(width: 8),
                          Text('Import Excel'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'template',
                      child: Row(
                        children: [
                          Icon(Icons.download, color: AppThemeColors.primary),
                          SizedBox(width: 8),
                          Text('Download Template'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppThemeColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppThemeColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Belum ada item',
            style: AppTypography.titleMedium.copyWith(
              color: AppThemeColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tambahkan produk atau layanan Anda',
            style: AppTypography.bodySmall.copyWith(
              color: AppThemeColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final authState = context.read<AuthCubit>().state;
    final isOwner = authState is AuthAuthenticated && authState.user.role == UserRole.owner;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgRadius,
        boxShadow: AppShadows.small,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOwner ? () => _navigateToForm(product: product) : null,
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppThemeColors.primarySurface,
                    borderRadius: AppRadius.mdRadius,
                    image: product.imageUrl != null && File(product.imageUrl!).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(product.imageUrl!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: product.imageUrl != null && File(product.imageUrl!).existsSync()
                      ? null
                      : Icon(
                          product.isService ? Icons.category : Icons.inventory_2,
                          color: AppThemeColors.primary,
                          size: 28,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          // Price badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeColors.success.withValues(alpha: 0.1),
                              borderRadius: AppRadius.smRadius,
                            ),
                            child: Text(
                              CurrencyFormatter.format(product.price),
                              style: AppTypography.labelSmall.copyWith(
                                color: AppThemeColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '/ ${product.unit}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppThemeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (product.isService)
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: AppThemeColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${product.durationDays} hari pengerjaan',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else if (product.isGoods)
                        Row(
                          children: [
                            Icon(
                              Icons.inventory,
                              size: 14,
                              color: AppThemeColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Stok: ${product.stock ?? 0}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppThemeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Actions (Only for Owner)
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppThemeColors.background,
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: AppThemeColors.textSecondary,
                        size: 18,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _navigateToForm(product: product);
                          break;
                        case 'delete':
                          _showDeleteDialog(product);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppThemeColors.primarySurface,
                                borderRadius: AppRadius.smRadius,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: AppThemeColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Ubah Data',
                              style: AppTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppThemeColors.error.withValues(alpha: 0.1),
                                borderRadius: AppRadius.smRadius,
                              ),
                              child: const Icon(
                                Icons.delete,
                                size: 16,
                                color: AppThemeColors.error,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Hapus',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppThemeColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    final authState = context.read<AuthCubit>().state;
    final isOwner = authState is AuthAuthenticated && authState.user.role == UserRole.owner;
    
    if (!isOwner) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: AppThemeColors.primaryGradient,
        borderRadius: AppRadius.fullRadius,
        boxShadow: AppShadows.purple,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah Item',
          style: AppTypography.labelMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
