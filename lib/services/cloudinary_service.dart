import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:veggieconnect/config/cloudinary_config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CloudinaryService {
  // Configure via config constants; you can override these at runtime if needed.
  static String cloudName = kCloudinaryCloudName; // e.g., 'mycloud'
  static String unsignedUploadPreset = kCloudinaryUploadPreset;
  static String defaultFolder = kCloudinaryFolder;
  
  // Product image configuration
  static String productUploadPreset = kCloudinaryProductUploadPreset;
  static String productFolder = kCloudinaryProductFolder;

  static Uri _endpoint() => Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  static bool get isConfigured => cloudName.isNotEmpty && unsignedUploadPreset.isNotEmpty;

  /// Upload bytes (web-friendly). Returns secure_url.
  static Future<String> uploadBytes(Uint8List bytes, {String? fileName, String? folder}) async {
    if (!isConfigured) {
      throw StateError('Cloudinary not configured. Set cloudName and unsignedUploadPreset.');
    }
    final req = http.MultipartRequest('POST', _endpoint())
      ..fields['upload_preset'] = unsignedUploadPreset
      ..fields['folder'] = folder ?? defaultFolder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName ?? 'avatar.jpg'));

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  /// Upload a local file (mobile/desktop). Returns secure_url.
  static Future<String> uploadFile(File file, {String? folder}) async {
    if (!isConfigured) {
      throw StateError('Cloudinary not configured. Set cloudName and unsignedUploadPreset.');
    }
    final req = http.MultipartRequest('POST', _endpoint())
      ..fields['upload_preset'] = unsignedUploadPreset
      ..fields['folder'] = folder ?? defaultFolder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  /// Upload product image bytes (web-friendly). Returns secure_url.
  static Future<String> uploadProductBytes(Uint8List bytes, {String? fileName}) async {
    if (!isConfigured) {
      throw StateError('Cloudinary not configured. Set cloudName and productUploadPreset.');
    }
    final req = http.MultipartRequest('POST', _endpoint())
      ..fields['upload_preset'] = productUploadPreset
      ..fields['folder'] = productFolder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName ?? 'product.jpg'));

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  /// Upload product image file (mobile/desktop). Returns secure_url.
  static Future<String> uploadProductFile(File file) async {
    if (!isConfigured) {
      throw StateError('Cloudinary not configured. Set cloudName and productUploadPreset.');
    }
    final req = http.MultipartRequest('POST', _endpoint())
      ..fields['upload_preset'] = productUploadPreset
      ..fields['folder'] = productFolder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception('Cloudinary upload failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  // Legacy compatibility methods (these now return null since we use Cloudinary URLs)
  
  /// Legacy method - returns null since we no longer store local profile images
  static Future<String?> getProfileImage(String userId) async {
    return null; // All profile images are now stored on Cloudinary
  }

  /// Legacy method - returns null since we no longer use local file paths
  static File? loadImageFromPath(String imagePath) {
    return null; // All images are now Cloudinary URLs
  }

  /// Pick image from web using file picker
  static Future<Uint8List?> pickImageFromWeb() async {
    if (!kIsWeb) {
      throw UnsupportedError('Use ImagePicker for mobile platforms');
    }
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    
    if (result != null && result.files.single.bytes != null) {
      return result.files.single.bytes;
    }
    return null;
  }
}
