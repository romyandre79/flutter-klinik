import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kreatif_otopart/logic/cubits/customer/customer_cubit.dart';
import 'package:kreatif_otopart/logic/cubits/customer/customer_state.dart';
import 'package:kreatif_otopart/data/models/customer.dart';
import 'package:kreatif_otopart/presentation/widgets/base_searchable_picker.dart';

class SearchableCustomerPicker extends StatelessWidget {
  final Customer? selectedCustomer;
  final Function(Customer?) onCustomerSelected;
  final String? label;
  final String? hint;
  final String? Function(Customer?)? validator;

  const SearchableCustomerPicker({
    super.key,
    this.selectedCustomer,
    required this.onCustomerSelected,
    this.label,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerCubit, CustomerState>(
      builder: (context, state) {
        List<Customer> customers = [];
        bool isLoading = state is CustomerInitial || state is CustomerLoading;

        if (state is CustomerLoaded) {
          customers = state.customers;
        }

        return BaseSearchablePicker<Customer>(
          title: 'Pilih Pelanggan',
          label: label,
          hint: hint,
          items: customers,
          isLoading: isLoading,
          selectedValue: selectedCustomer,
          itemLabel: (customer) => customer.name,
          itemSubtitle: (customer) => customer.phone ?? '',
          searchMatcher: (customer, query) => 
              customer.name.toLowerCase().contains(query.toLowerCase()) ||
              (customer.phone != null && customer.phone!.contains(query)),
          onSelected: onCustomerSelected,
          onRefresh: () => context.read<CustomerCubit>().loadCustomers(),
          validator: validator,
          icon: Icons.person,
          emptyMessage: 'Pelanggan tidak ditemukan',
        );
      },
    );
  }
}
