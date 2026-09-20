import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../domain/models/expense_draft.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  String? _imagePath;
  bool _isProcessing = false;
  String _processingStep = '';

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage({ImageSource source = ImageSource.camera}) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() {
      _imagePath = image.path;
      _isProcessing = true;
      _processingStep = 'Analisi dello scontrino...';
    });

    await _processImage(image.path);
  }

  Future<void> _processImage(String path) async {
    try {
      // Step 1: Receipt recognition + pipeline
      _updateStep('Analisi dello scontrino...');
      final expenseService = ref.read(receiptExpenseServiceProvider);
      final draft = await expenseService.processReceipt(path);
      
      if (!mounted) return;
      
      _updateStep('Sto preparando la spesa...');
      
      // Navigate to add transaction with prefilled data
      _navigateToAddTransaction(draft);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStep = '';
        });
      }
    }
  }

  void _updateStep(String step) {
    if (mounted) {
      setState(() => _processingStep = step);
    }
  }

  void _navigateToAddTransaction(ExpenseDraft draft) {
    context.push('/add', extra: draft.toMap());
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Errore elaborazione'),
        content: Text(
          'Non è stato possibile leggere lo scontrino.\n'
          'Puoi riprovare con una foto più nitida oppure inserire la spesa manualmente.\n\n'
          'Dettaglio: $error',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Inserisci manualmente'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_imagePath != null) {
                _processImage(_imagePath!);
              }
            },
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona Scontrino'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _processingStep,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_imagePath == null) {
      return _buildNoImageState();
    }

    return _buildWithImageState();
  }

  Widget _buildNoImageState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 96, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'Pronto per scansionare lo scontrino',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _pickImage(source: ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('SCATTA FOTO'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _pickImage(source: ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('SCEGLI DA GALLERIA'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithImageState() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Image.file(File(_imagePath!), fit: BoxFit.contain),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _imagePath = null),
                icon: const Icon(Icons.refresh),
                label: const Text('RIFAI FOTO'),
              ),
              FilledButton.icon(
                onPressed: () => _processImage(_imagePath!),
                icon: const Icon(Icons.send),
                label: const Text('ELABORA'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}