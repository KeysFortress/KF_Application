import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:domain/models/stored_identity.dart';
import 'package:infrastructure/interfaces/idevices_service.dart';
import 'package:infrastructure/interfaces/iidentity_manager.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:domain/models/key_dto.dart';
import 'package:domain/converters/binary_converter.dart';

class IdentityManager implements IIdentityManager {
  late ISignatureService _signatureService;
  late IlocalStorage _localStorage;
  late IDevicesService _devicesService;

  IdentityManager(ISignatureService signatureService, IlocalStorage storage,
      IDevicesService devicesService) {
    _signatureService = signatureService;
    _localStorage = storage;
    _devicesService = devicesService;
  }

  @override
  Future<KeyDto> generateIdentity() async {
    var result = await _signatureService.generatePrivateKey();
    var privateKeyData = await result.extractPrivateKeyBytes();
    var publicKeyData = await result.extractPublicKey();
    var key = publicKeyData.bytes;

    return KeyDto(
      publicKey: BianaryConverter.toHex(privateKeyData),
      privateKey: BianaryConverter.toHex(key),
    );
  }

  @override
  Future<List<StoredIdentity>> getSecrets() async {
    var secretsData = await _localStorage.get("identities");
    if (secretsData == null) return [];

    List<dynamic> data = jsonDecode(secretsData);
    List<StoredIdentity> result = [];
    data.forEach((element) {
      var current = StoredIdentity.fromJson(element);
      result.add(current);
    });

    return result;
  }

  @override
  Future<List<StoredIdentity>> importSecrets(
      List<StoredIdentity> secrets) async {
    List<StoredIdentity> missing = [];
    var secretsData = await _localStorage.get("identities");
    List<dynamic> data = [];
    if (secretsData != null) data = jsonDecode(secretsData);

    List<StoredIdentity> result = [];
    data.forEach((element) {
      var current = StoredIdentity.fromJson(element);
      result.add(current);
    });

    missing = result
        .where((element) =>
            secrets.firstWhereOrNull(
              (incomingSecret) =>
                  incomingSecret.privateKey == element.privateKey,
            ) ==
            null)
        .toList();

    secrets
        .where(
      (element) =>
          result.firstWhereOrNull(
              (existing) => existing.privateKey == element.privateKey) ==
          null,
    )
        .forEach((element) {
      result.add(element);
    });
    var json = result.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await _localStorage.set("identities", jsonData);
    return missing;
  }

  @override
  Future<bool> setSecret(StoredIdentity secret) async {
    var secretsData = await _localStorage.get("identities");
    if (secretsData == null) {
      List<StoredIdentity> result = [];
      result.add(secret);
      var json = result.map((e) => e.toJson()).toList();
      var jsonData = jsonEncode(json);
      await _localStorage.set("identities", jsonData);
      return true;
    }

    List<dynamic> data = jsonDecode(secretsData);
    List<StoredIdentity> result = [];
    data.forEach((element) {
      var current = StoredIdentity.fromJson(element);
      result.add(current);
    });

    result.add(secret);
    var json = result.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await _localStorage.set("identities", jsonData);
    _devicesService.syncDevices();
    return true;
  }
}
