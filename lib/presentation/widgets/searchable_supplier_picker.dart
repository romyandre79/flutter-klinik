import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/supplier/supplier_state.dart';
import 'package:kreatif_otopart/data/models/supplier.dart';
import 'package:kreatif_otopart/presentation/widgets/base_searchable_picker.dart';

class SearchableSupplierPicker extends StatelessWidget {
  final Supplier? selectedSupplier;
  final Function(Supplier) onSupplierSelected;
  final String? label;
  final String? hint;
  final String? Function(Supplier?)? validator;

  const SearchableSupplierPicker({
    super.key,
    this.selectedSupplier,
    required this.onSupplierSelected,
    this.label,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupplierCubit, SupplierState>(
      builder: (context, state) {
        List<Supplier> suppliers = [];
        bool isLoading = state is SupplierInitial || state is SupplierLoading;

        if (state is SupplierLoaded) {
          suppliers = state.suppliers;
        }

        return BaseSearchablePicker<Supplier>(
          title: 'Pilih Supplier',
          label: label,
          hint: hint,
          items: suppliers,
          isLoading: isLoading,
          selectedValue: selectedSupplier,
          itemLabel: (supplier) => supplier.name,
          itemSubtitle: (supplier) => supplier.address ?? '',
          searchMatcher: (supplier, query) => 
              supplier.name.toLowerCase().contains(query.toLowerCase()) ||
              (supplier.address != null && supplier.address!.toLowerCase().contains(query.toLowerCase())),
          onSelected: onSupplierSelected,
          onRefresh: () => context.read<SupplierCubit>().loadSuppliers(),
          validator: validator,
          icon: Icons.business,
          emptyMessage: 'Supplier tidak ditemukan',
        );
      },
    );
  }
}
