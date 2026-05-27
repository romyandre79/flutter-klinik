import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/unit/unit_state.dart';
import 'package:kreatif_otopart/data/models/unit.dart';
import 'package:kreatif_otopart/presentation/widgets/base_searchable_picker.dart';

class SearchableUnitPicker extends StatelessWidget {
  final String? selectedUnit;
  final Function(String) onUnitSelected;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final List<String>? allowedUnits; // Filter list from Cubit
  final List<String>? manualUnits;  // Use this list instead of Cubit

  const SearchableUnitPicker({
    super.key,
    this.selectedUnit,
    required this.onUnitSelected,
    this.label,
    this.hint,
    this.validator,
    this.allowedUnits,
    this.manualUnits,
  });

  @override
  Widget build(BuildContext context) {
    if (manualUnits != null) {
      final items = manualUnits!.map((name) => Unit(name: name)).toList();
      return _buildPicker(context, items, false);
    }

    return BlocBuilder<UnitCubit, UnitState>(
      builder: (context, state) {
        List<Unit> units = [];
        bool isLoading = state is UnitInitial || state is UnitLoading;
        
        if (state is UnitLoaded) {
          units = state.units;
        } else if (state is UnitOperationSuccess) {
          units = state.units;
        }

        if (allowedUnits != null) {
          units = units.where((u) => allowedUnits!.contains(u.name)).toList();
        }

        return _buildPicker(context, units, isLoading);
      },
    );
  }

  Widget _buildPicker(BuildContext context, List<Unit> units, bool isLoading) {
    return BaseSearchablePicker<Unit>(
      title: 'Pilih Satuan',
      label: label,
      hint: hint,
      items: units,
      isLoading: isLoading,
      selectedValue: units.any((u) => u.name == selectedUnit) 
        ? units.firstWhere((u) => u.name == selectedUnit) 
        : null,
      itemLabel: (unit) => unit.name,
      searchMatcher: (unit, query) => unit.name.toLowerCase().contains(query.toLowerCase()),
      onSelected: (unit) => onUnitSelected(unit.name),
      onRefresh: manualUnits != null ? null : () => context.read<UnitCubit>().loadUnits(),
      validator: (val) => validator?.call(val?.name),
      icon: Icons.straighten,
      emptyMessage: 'Satuan tidak ditemukan',
    );
  }
}
