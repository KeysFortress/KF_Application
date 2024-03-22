import 'dart:convert';

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
      final certData = await rootBundle.loadString(certPath);

      var x509PEM = X509Utils.parseChainString(certData);
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
}
