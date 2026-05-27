import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/core/utils/currency_formatter.dart';
import 'package:kreatif_pos/data/models/customer.dart';
import 'package:kreatif_pos/logic/cubits/customer/customer_cubit.dart';
import 'package:kreatif_pos/logic/cubits/customer/customer_state.dart';
import 'package:kreatif_pos/presentation/screens/customers/customer_form_screen.dart';
import 'package:kreatif_pos/presentation/screens/customers/customer_detail_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kreatif_pos/core/services/export_service.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    context.read<CustomerCubit>().loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<CustomerCubit>().loadCustomers();
      }
    });
  }

  void _performSearch(String query) {
    context.read<CustomerCubit>().searchCustomers(query);
  }

  void _navigateToForm({Customer? customer}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CustomerCubit>(),
          child: CustomerFormScreen(customer: customer),
        ),
      ),
    );
  }

  void _navigateToDetail(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CustomerCubit>(),
          child: CustomerDetailScreen(customer: customer),
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

          // Content
          Expanded(
            child: BlocConsumer<CustomerCubit, CustomerState>(
              listener: (context, state) {
                if (state is CustomerOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppThemeColors.success,
                    ),
                  );
                } else if (state is CustomerError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppThemeColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is CustomerLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppThemeColors.primary,
                    ),
                  );
                }

                final customers = context.read<CustomerCubit>().customers;

                if (customers.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () => context.read<CustomerCubit>().loadCustomers(),
                  color: AppThemeColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return _buildCustomerCard(customer);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
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
        context.read<CustomerCubit>().importCustomers(file);
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
    final excel = Excel.createExcel();
    final sheet = excel['Template Pelanggan'];
    
    // Headers: Name, Phone, Address, Notes
    List<String> headers = ['Nama Pelanggan', 'Nomor HP', 'Alamat', 'Catatan'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    // Example Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('Budi Santoso');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('081234567890');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('Jl. Merdeka No. 45, Jakarta');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('Pelanggan VIP');

    excel.delete('Sheet1');

    final fileName = 'Template_Import_Pelanggan.xlsx';
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
               SharePlus.instance.share(ShareParams(files: [XFile(filePath)], text: 'Template Import Pelanggan'));
            },
          ),
        ),
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppThemeColors.headerGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Row(
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
                      'Pelanggan',
                      style: AppTypography.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Search toggle
                  GestureDetector(
                    onTap: _toggleSearch,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Icon(
                        _isSearching ? Icons.close : Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
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

              // Search Field
              if (_isSearching) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau nomor HP...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppThemeColors.textHint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppThemeColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    onChanged: _performSearch,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
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
                Icons.people_outline,
                size: 40,
                color: AppThemeColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Belum ada pelanggan',
              style: AppTypography.titleMedium.copyWith(
                color: AppThemeColors.textPrimary,
              ),
            ),
           
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
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
          onTap: () => _navigateToDetail(customer),
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: customer.isLoyalCustomer
                        ? AppThemeColors.warning.withValues(alpha: 0.1)
                        : AppThemeColors.primarySurface,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: customer.isLoyalCustomer
                      ? const Icon(
                          Icons.star,
                          color: AppThemeColors.warning,
                          size: 26,
                        )
                      : Center(
                          child: Text(
                            customer.name.substring(0, 1).toUpperCase(),
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppThemeColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customer.name,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (customer.isLoyalCustomer) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppThemeColors.warning.withValues(alpha: 0.1),
                                borderRadius: AppRadius.smRadius,
                              ),
                              child: Text(
                                'LOYAL',
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppThemeColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          customer.phone!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppThemeColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          // Order count
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeColors.primarySurface,
                              borderRadius: AppRadius.smRadius,
                            ),
                            child: Text(
                              '${customer.totalOrders} order',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppThemeColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Total spent
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
                              CurrencyFormatter.formatCompact(customer.totalSpent),
                              style: AppTypography.labelSmall.copyWith(
                                color: AppThemeColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppThemeColors.background,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: AppThemeColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
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
          'Tambah',
          style: AppTypography.labelMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
