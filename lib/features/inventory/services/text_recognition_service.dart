import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Subsistema B del patrón Facade.
/// Encapsula el reconocimiento óptico de caracteres (OCR) usando
/// Google ML Kit. Recibe un archivo de imagen y devuelve el texto crudo
/// extraído, procesado completamente on-device (sin enviar datos a la nube).
class TextRecognitionService {
  Future<String?> extractText(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      return text.isEmpty ? null : text;
    } finally {
      textRecognizer.close();
    }
  }
}
