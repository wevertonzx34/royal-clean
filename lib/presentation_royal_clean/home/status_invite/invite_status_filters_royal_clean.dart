import 'package:flutter/material.dart';

class InviteStatusFiltersRoyalClean extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedProfile;
  final String selectedStatus;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<String> onStatusChanged;

  const InviteStatusFiltersRoyalClean({
    super.key,
    required this.searchController,
    required this.selectedProfile,
    required this.selectedStatus,
    required this.onProfileChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar convite',
            hintText: 'Nome, WhatsApp, código ou função',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedProfile,
          decoration: const InputDecoration(
            labelText: 'Perfil',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'Todos', child: Text('Todos')),
            DropdownMenuItem(value: 'Mestre', child: Text('Mestre')),
            DropdownMenuItem(value: 'Cliente', child: Text('Cliente')),
            DropdownMenuItem(value: 'Colaborador', child: Text('Colaborador')),
            DropdownMenuItem(value: 'Promotor', child: Text('Promotor')),
          ],
          onChanged: (value) {
            if (value == null) return;
            onProfileChanged(value);
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedStatus,
          decoration: const InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'Todos', child: Text('Todos')),
            DropdownMenuItem(value: 'Ativo', child: Text('Ativo')),
            DropdownMenuItem(value: 'Usado', child: Text('Usado')),
            DropdownMenuItem(value: 'Processing', child: Text('Processing')),
          ],
          onChanged: (value) {
            if (value == null) return;
            onStatusChanged(value);
          },
        ),
      ],
    );
  }
}
