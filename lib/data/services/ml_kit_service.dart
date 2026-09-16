import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MLKitService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<String> recognizeText(String imagePath) async {
    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text.trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}