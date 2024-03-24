import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/services.dart';
import 'package:infrastructure/interfaces/icertificate_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';

class CertificateService implements ICertificateService {
  late IlocalStorage _localStorage;
  final certPath = 'lib/certificates/cert.pem';
  final keyPath = 'lib/certificates/key.pem';

  CertificateService(IlocalStorage storage) {
    _localStorage = storage;
  }

  @override
  Future<Map<String, ByteData>> get() async {
    try {
      var certData = await rootBundle.load(certPath);
      var keyData = await rootBundle.load(keyPath);

      var certificate = await _localStorage.get("certificate_override");
      var keyOverride = await _localStorage.get("key_override");

      if (certificate != null && keyOverride != null) {
        certData = base64.decode(certificate).buffer.asByteData();
        keyData = base64.decode(keyOverride).buffer.asByteData();
      }

      return {"Certificate": certData, "Key": keyData};
    } catch (ex) {
      return {};
    }
  }

  @override
  Future<List<X509CertificateData>> read() async {
    try {
      var certData = await rootBundle.load(certPath);

      var certificate = await _localStorage.get("certificate_override");
      if (certificate != null) {
        certData = base64.decode(certificate).buffer.asByteData();
      }

      var data = new String.fromCharCodes(certData.buffer.asUint8List());
      var x509PEM = X509Utils.parseChainString(data);
      return x509PEM;
    } catch (ex) {
      return [];
    }
  }

  @override
  Future<bool> update(Uint8List data, Uint8List key) async {
    try {
      await _localStorage.set("certificate_override", base64.encode(data));
      await _localStorage.set("key_override", base64.encode(data));
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> importCertificate(File file) async {
    try {
      var bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      // For all of the entries in the archive
      for (var file in archive.files) {
        // If it's a file and not a directory
        if (file.isFile) {
          var data = file.content;

          var fileData = new String.fromCharCodes(data);

          var isCert = isCertificate(fileData);
          var isPk = isPrivateKey(fileData);

          if (isPk) {
            await _localStorage.set("key_override", base64.encode(data));
          }

          if (isCert) {
            await _localStorage.set(
              "certificate_override",
              base64.encode(data),
            );
          }
        }
      }
      return true;
    } catch (ex) {
      return false;
    }
  }

  bool isCertificate(String pemContent) {
    return pemContent.contains('BEGIN CERTIFICATE') &&
        pemContent.contains('END CERTIFICATE');
  }

  bool isPrivateKey(String pemContent) {
    return pemContent.contains('PRIVATE KEY');
  }

  @override
  Future<String?> getKeyPassword() async {
    return await _localStorage.get("key_override_password");
  }

  @override
  Future<bool> setCertificatePassword(String password) async {
    try {
      await _localStorage.set("key_override_password", password);
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<Map<String, ByteData>> getSystemDefaultIdentities() async {
    try {
      var certData = await rootBundle.load(certPath);
      var keyData = await rootBundle.load(keyPath);

      return {"Certificate": certData, "Key": keyData};
    } catch (ex) {
      return {};
    }
  }
}
