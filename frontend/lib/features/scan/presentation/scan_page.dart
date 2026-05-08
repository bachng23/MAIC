import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/providers.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  File? _pickedImage;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;
    setState(() {
      _pickedImage = File(picked.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(scanControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Medication')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Align the medication label inside the frame',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Make sure the label is clear and well lit before scanning.'),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _pickedImage == null
                    ? const Center(child: Text('No image selected'))
                    : Image.file(_pickedImage!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: controller.isLoading ? null : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera),
            label: const Text('Scan Now'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.isLoading ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Upload from Photos'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: controller.isLoading || _pickedImage == null
                ? null
                : () => ref.read(scanControllerProvider).scanAndCreateMedication(_pickedImage!),
            child: Text(controller.isLoading ? 'Scanning...' : 'Run OCR + Save Medication'),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Text(controller.error!, style: const TextStyle(color: Colors.red)),
          ],
          if (controller.scanResult != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(controller.scanResult!.name),
                subtitle: Text(controller.scanResult!.dosage ?? 'Dosage not detected'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ),
          ],
          if (controller.createdMedication != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Medication Saved'),
                subtitle: Text('ID: ${controller.createdMedication!.id}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
