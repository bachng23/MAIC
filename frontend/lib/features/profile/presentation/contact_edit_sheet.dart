import 'package:flutter/material.dart';

import '../../shared/models/api_models.dart' show EmergencyContact;

class ContactEditSheet extends StatefulWidget {
  const ContactEditSheet({super.key, this.initialContact});

  final EmergencyContact? initialContact;

  @override
  State<ContactEditSheet> createState() => _ContactEditSheetState();
}

class _ContactEditSheetState extends State<ContactEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _relationCtrl;

  static const _relationChips = [
    'Son',
    'Daughter',
    'Spouse',
    'Parent',
    'Sibling',
    'Doctor',
    'Caregiver',
    'Friend',
  ];

  String? _selectedChip;

  @override
  void initState() {
    super.initState();
    final c = widget.initialContact;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _relationCtrl = TextEditingController(text: c?.relation ?? '');
    if (c != null && _relationChips.contains(c.relation)) {
      _selectedChip = c.relation;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  void _selectChip(String chip) {
    setState(() {
      if (_selectedChip == chip) {
        _selectedChip = null;
        _relationCtrl.clear();
      } else {
        _selectedChip = chip;
        _relationCtrl.text = chip;
      }
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    final contact = EmergencyContact(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      relation: _relationCtrl.text.trim(),
    );
    Navigator.of(context).pop(contact);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialContact != null;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DDE6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'Edit Contact' : 'Add Emergency Contact',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B3A70),
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Full Name', Icons.person_outline),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Phone field
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 20),

            // Relation chips
            const Text(
              'Relation',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C616C),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _relationChips.map((chip) {
                final selected = _selectedChip == chip;
                return ChoiceChip(
                  label: Text(chip),
                  selected: selected,
                  onSelected: (_) => _selectChip(chip),
                  selectedColor: const Color(0xFF0066CC),
                  backgroundColor: const Color(0xFFF2F4F7),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF2D3A4A),
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF0066CC)
                          : Colors.transparent,
                    ),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Custom relation text field
            TextFormField(
              controller: _relationCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                'Or type a custom relation…',
                Icons.people_outline,
              ),
              onChanged: (v) {
                // If user types a value that doesn't match a chip, deselect
                if (_selectedChip != null && v.trim() != _selectedChip) {
                  setState(() => _selectedChip = null);
                }
              },
            ),
            const SizedBox(height: 28),

            // Save button
            FilledButton(
              onPressed: _onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0066CC),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              child: Text(isEdit ? 'Save Changes' : 'Add Contact'),
            ),
            const SizedBox(height: 10),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4C616C),
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF0066CC)),
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0066CC), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF4C616C)),
    );
  }
}
