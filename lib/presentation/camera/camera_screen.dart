import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/seed_categories.dart';
import '../../../../data/services/llm_service.dart';
import '../../../../data/services/ml_kit_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final MLKitService _mlKitService = MLKitService();
  late final LLMService _llmService = LLMService(
    apiKey: String.fromEnvironment('LLM_API_KEY'),
  );

  String? _imagePath;
  String? _recognizedText;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() {
      _imagePath = image.path;
      _recognizedText = null;
      _isProcessing = false;
    });

    await _processImage(image.path);
  }

  Future<void> _processImage(String path) async {
    setState(() => _isProcessing = true);
    try {
      final text = await _mlKitService.recognizeText(path);
      if (!mounted) return;
      setState(() => _recognizedText = text);

      // Prepara contesto categorie per il prompt
      final cats = seedCategories.map((c) => '"${c.name}"').join(', ');
      if (!_llmService.isConfigured) {
        // Flusso alternativo B: AI non configurata -> form di inserimento manuale pulito
        _navigateToPrefillForm({});
        return;
      }
      final parsed = await _llmService.parseReceiptText(text, cats);
      _navigateToPrefillForm(parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore elaborazione: $e')),
      );
      // Degrado sul form manuale pulito
      _navigateToPrefillForm({});
    }
  }

  void _navigateToPrefillForm(Map<String, dynamic> aiResult) {
    if (!mounted) return;
    // Naviga e passa il risultato AI pre-popolato
    context.push('/add', extra: aiResult);
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
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _imagePath == null
              ? _buildNoImageState()
              : _buildWithImageState(),
    );
  }

  Widget _buildNoImageState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 96, color: Colors.grey),
          const SizedBox(height: 24),
          const Text('Pronto per scansionare lo scontrino',
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: const Text('SCATTA FOTO'),
            style: ElevatedButton.styleFrom(
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
        if (_recognizedText != null)
          Expanded(
            flex: 1,
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Testo Riconosciuto:\n$_recognizedText',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}