import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spesapp/data/services/temp_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Test Temp File Service', () {
    late TempFileService service;

    setUp(() {
      service = TempFileService();
    });

    // TEST-026: deleteFile removes file successfully
    test('TEST-026: deleteFile removes file successfully', () async {
      final tempDir = await Directory.systemTemp.createTemp('spesapp_temp_test_');
      final testFile = File('${tempDir.path}/spesapp_test_delete.txt');
      await testFile.writeAsString('test content');
      
      expect(await testFile.exists(), true);
      
      await service.deleteFile(testFile.path);
      
      expect(await testFile.exists(), false);
      await tempDir.delete(recursive: true);
    });

    // TEST-027: deleteFile handles non-existent file
    test('TEST-027: deleteFile handles non-existent file gracefully', () async {
      final nonExistentPath = '${Directory.systemTemp.path}/nonexistent_spesapp_file_12345.txt';
      
      await service.deleteFile(nonExistentPath);
      
      expect(true, true);
    });
  });
}
