import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  String? _tempImagePath;
  bool _isProcessing = false;
  String _processingStep = '';

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

  bool _isImageValid() =>
      _imagePath != null && File(_imagePath!).existsSync();

  @override
  void dispose() {
    if (_tempImagePath != null) {
      final file = File(_tempImagePath!);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('[CameraScreen] File temporaneo eliminato al dispose');
      }
    }
    _tempImagePath = null;
    super.dispose();
  }

  Future<void> _pickImage({ImageSource source = ImageSource.camera}) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    String? tempImagePath;
    try {
      // Copy image to controlled temp directory with unique name
      final tempDir = await getTemporaryDirectory();
      final tempName =
          'receipt_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final newPath = p.join(tempDir.path, tempName);

      await image.saveTo(newPath);
      tempImagePath = newPath;
      _tempImagePath = newPath;
    } catch (e) {
      debugPrint('CameraScreen._pickImage: failed to copy to temp: $e');
    }

    // Verify file exists before processing
    final pathToProcess = tempImagePath ?? image.path;
    if (!File(pathToProcess).existsSync()) {
      _showUserFriendlyError('Foto non disponibile. Riprova a scattare.');
      return;
    }

    setState(() {
      _imagePath = pathToProcess;
      _isProcessing = false;
      _processingStep = '';
    });
  }

  Future<void> _processImage(String path) async {
    try {
      // Verify file exists before OCR processing
      if (!File(path).existsSync()) {
        _showUserFriendlyError('Foto non disponibile. Riprova a scattare.');
        setState(() => _imagePath = null);
        return;
      }

      // Step 1: Receipt recognition + pipeline
      _updateStep('Analisi dello scontrino...');
      final expenseService = ref.read(receiptExpenseServiceProvider);
      final draft = await expenseService.processReceipt(path);

      if (!mounted) return;

      _updateStep('Sto preparando la spesa...');

      // Navigate to add transaction with prefilled data
      _navigateToAddTransaction(draft);
    } on PathNotFoundException {
      _showUserFriendlyError('Foto non disponibile. Riprova a scattare.');
      setState(() => _imagePath = null);
    } catch (e) {
      debugPrint('CameraScreen._processImage error: $e');
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

  void _showUserFriendlyError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Errore'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Errore elaborazione'),
        content: const Text(
          'Non è stato possibile leggere lo scontrino.\n'
          'Puoi riprovare con una foto più nitida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
          if (_tempImagePath != null && File(_tempImagePath!).existsSync())
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted && _tempImagePath != null) {
                  _processImage(_tempImagePath!);
                }
              },
              child: const Text('Riprova'),
            ),
        ],
      ),
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
            'Recupera lo scontrino da scansionare',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _pickImage(source: ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('SCATTA FOTO'),
            style: ElevatedButton.styleFrom(
              fixedSize: const Size(250, 50),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _pickImage(source: ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('SCEGLI DA GALLERIA'),
            style: OutlinedButton.styleFrom(
              fixedSize: const Size(250, 50),
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
            child: _buildPreview(),
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
              OutlinedButton.icon(
                onPressed: () => _pickImage(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('GALLERIA'),
              ),
              FilledButton.icon(
                onPressed: _isImageValid()
                    ? () => _processImage(_imagePath!)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isImageValid() ? null : Colors.grey,
                ),
                icon: const Icon(Icons.send),
                label: const Text('ELABORA'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final isValid = _isImageValid();
    if (!isValid) {
      return _placeholder();
    }
    return Image.file(
      File(_imagePath!),
      fit: BoxFit.contain,
       errorBuilder: (_, _, _) => _placeholder(),
     );
   }

   Widget _placeholder() => const Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(Icons.camera_alt, size: 64, color: Colors.grey),
             SizedBox(height: 12),
             Text(
               'Scatta o seleziona uno scontrino',
               style: TextStyle(color: Colors.grey),
             ),
           ],
         ),
       );
}
