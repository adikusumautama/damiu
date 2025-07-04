import 'package:flutter/material.dart';
import 'package:damiu/models/customer_model.dart';

class CustomerAutocompleteField extends StatelessWidget {
  final List<Customer> customers;
  final TextEditingController controller;
  final void Function(Customer?)? onSelected;

  const CustomerAutocompleteField({
    super.key,
    required this.customers,
    required this.controller,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Customer>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<Customer>.empty();
        }
        return customers.where((Customer c) =>
            c.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (Customer c) => c.name,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sinkronisasi dua arah agar controller utama selalu update
        textController.addListener(() {
          if (controller.text != textController.text) {
            controller.text = textController.text;
          }
        });
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'Nama Pelanggan *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
        );
      },
      onSelected: (customer) {
        controller.text = customer != null ? customer.name : '';
        if (onSelected != null) onSelected!(customer);
      },
    );
  }
}
