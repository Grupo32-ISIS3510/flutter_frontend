import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Subsistema A del patrón Facade.
/// Encapsula el acceso a la cámara del dispositivo: solicitud de permisos
/// en tiempo de ejecución y captura de foto optimizada para OCR.
class CameraService {
  final ImagePicker _picker = ImagePicker();

  Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo == null) return null;
    return File(photo.path);
  }
}
