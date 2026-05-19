import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../scan/presentation/med_blue_tokens.dart';
import '../domain/user_profile_info.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _address;
  late final TextEditingController _allergies;
  late final TextEditingController _conditions;
  String? _bloodType;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _age = TextEditingController();
    _address = TextEditingController();
    _allergies = TextEditingController();
    _conditions = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedFromProfile());
  }

  void _seedFromProfile() {
    final current = ref.read(profileControllerProvider).profile;
    _name.text = current.name;
    _age.text = current.age?.toString() ?? '';
    _address.text = current.address;
    _allergies.text = current.allergies;
    _conditions.text = current.medicalConditions;
    setState(() {
      _bloodType = current.bloodType.isEmpty ? null : current.bloodType;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _address.dispose();
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ageText = _age.text.trim();
    final profile = UserProfileInfo(
      name: _name.text.trim(),
      age: ageText.isEmpty ? null : int.parse(ageText),
      address: _address.text.trim(),
      bloodType: _bloodType ?? '',
      allergies: _allergies.text.trim(),
      medicalConditions: _conditions.text.trim(),
    );

    final ok = await ref.read(profileControllerProvider).save(profile);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
      context.pop();
    } else {
      final err = ref.read(profileControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Could not save profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(profileControllerProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: MedBlueTokens.background,
      appBar: AppBar(
        backgroundColor: MedBlueTokens.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MedBlueTokens.primaryDark),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w800, color: MedBlueTokens.primaryDark, fontSize: 20),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _SectionHeader(title: 'Personal Info', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: MedBlueTokens.inputDecoration(hint: 'Full name', label: 'Name'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: MedBlueTokens.inputDecoration(hint: 'e.g. 42', label: 'Age'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      if (n == null) return 'Enter a valid age.';
                      if (n < 1 || n > 130) return 'Age must be between 1 and 130.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: MedBlueTokens.inputDecoration(hint: 'Street, city, state', label: 'Address'),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Medical Info', icon: Icons.medical_information_outlined),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _bloodType,
                    decoration: MedBlueTokens.inputDecoration(hint: 'Select blood type', label: 'Blood Type'),
                    items: UserProfileInfo.bloodTypeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _bloodType = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _allergies,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: MedBlueTokens.inputDecoration(
                      hint: 'e.g. Penicillin, peanuts',
                      label: 'Allergies',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _conditions,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: MedBlueTokens.inputDecoration(
                      hint: 'e.g. Hypertension, asthma',
                      label: 'Medical Conditions',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
              decoration: BoxDecoration(
                color: MedBlueTokens.background,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: controller.isLoading ? null : _submit,
                style: MedBlueTokens.primaryFilled(),
                child: controller.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MedBlueTokens.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MedBlueTokens.primaryDark,
          ),
        ),
      ],
    );
  }
}
