import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_pos/core/theme/app_theme.dart';
import 'package:kreatif_pos/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_pos/logic/cubits/supplier/supplier_state.dart';
import 'package:kreatif_pos/presentation/screens/purchasing/supplier_form_screen.dart';
import 'package:kreatif_pos/core/services/export_service.dart';
import 'package:kreatif_pos/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_pos/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_pos/data/models/user.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger load on init
    context.read<SupplierCubit>().loadSuppliers();
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
        context.read<SupplierCubit>().importSuppliers(file);
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
    final sheet = excel['Template Supplier'];
    
    // Headers: Name, Contact Person, Phone, Email, Address
    List<String> headers = ['Nama Supplier', 'Contact Person', 'Nomor HP', 'Email', 'Alamat'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    // Example Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('PT. Supplier Maju');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('Bapak Andi');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('081298765432');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('info@suppliermaju.com');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = TextCellValue('Jl. Industri No. 99, Surabaya');

    excel.delete('Sheet1');

    final fileName = 'Template_Import_Supplier.xlsx';
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
            onPressed: () async {
               await SharePlus.instance.share(
                 ShareParams(files: [XFile(filePath)], text: 'Template Import Supplier'),
               );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final isOwner = authState is AuthAuthenticated && authState.user.role == UserRole.owner;

    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(context, isOwner),

          // Content
          Expanded(
            child: BlocConsumer<SupplierCubit, SupplierState>(
              listener: (context, state) {
                if (state is SupplierOperationSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.success),
                  );
                } else if (state is SupplierError) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.error),
                  );
                }
              },
              builder: (context, state) {
                if (state is SupplierLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is SupplierLoaded) {
                  if (state.suppliers.isEmpty) {
                    return const Center(child: Text('Tidak ada data Supplier'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.suppliers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final supplier = state.suppliers[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppThemeColors.primarySurface,
                            child: Text(supplier.name[0].toUpperCase()),
                          ),
                          title: Text(supplier.name, style: AppTypography.titleMedium),
                          subtitle: Text(supplier.contactPerson ?? supplier.phone ?? 'No contact info'),
                          trailing: isOwner ? const Icon(Icons.chevron_right) : null,
                          onTap: isOwner
                              ? () {
                                  final cubit = context.read<SupplierCubit>();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: cubit,
                                        child: SupplierFormScreen(supplier: supplier),
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                  );
                } else if (state is SupplierError) {
                  return Center(child: Text(state.message));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, isOwner),
    );
  }

  Widget _buildHeader(BuildContext context, bool isOwner) {
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
                  'Suppliers',
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

  Widget _buildFAB(BuildContext context, bool isOwner) {
    if (!isOwner) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: AppThemeColors.primaryGradient,
        borderRadius: AppRadius.fullRadius,
        boxShadow: AppShadows.purple,
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          final cubit = context.read<SupplierCubit>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: const SupplierFormScreen(),
              ),
            ),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah Supplier',
          style: AppTypography.labelMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
