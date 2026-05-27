import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/core/theme/app_theme.dart';
import 'package:kreatif_otopart/data/models/supplier.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_state.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/auth/auth_state.dart';
import 'package:kreatif_otopart/data/models/user.dart';

class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplier; // If null, it's add mode

  const SupplierFormScreen({super.key, this.supplier});

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactController = TextEditingController(text: widget.supplier?.contactPerson ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _emailController = TextEditingController(text: widget.supplier?.email ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final supplier = Supplier(
        id: widget.supplier?.id,
        name: _nameController.text.trim(),
        contactPerson: _contactController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        createdAt: widget.supplier?.createdAt,
      );

      if (widget.supplier == null) {
        context.read<SupplierCubit>().addSupplier(supplier);
      } else {
        context.read<SupplierCubit>().updateSupplier(supplier);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Ubah Data Supplier' : 'Tambah Data Supplier'),
        actions: [
          if (isEditing && context.read<AuthCubit>().state is AuthAuthenticated && (context.read<AuthCubit>().state as AuthAuthenticated).user.role == UserRole.owner)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Supplier?'),
                    content: const Text('Are you sure you want to delete this supplier? This action cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<SupplierCubit>().deleteSupplier(widget.supplier!.id!);
                        },
                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: BlocListener<SupplierCubit, SupplierState>(
        listener: (context, state) {
          if (state is SupplierOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            Navigator.pop(context);
          } else if (state is SupplierError) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppThemeColors.error),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Supplier Name *'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(labelText: 'Contact Person'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Update Supplier' : 'Save Supplier'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
