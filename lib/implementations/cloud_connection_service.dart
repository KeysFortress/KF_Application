import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:domain/models/cloud_connection_code.dart';
import 'package:infrastructure/interfaces/icloud_service.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:domain/models/http_request.dart';

class CloudConnectionService implements ICloudService {
  late IHttpProviderService _providerService;
  late IlocalStorage _localStorage;
  late ISignatureService _signatureService;

  CloudConnectionService(IHttpProviderService httpProvider,
      IlocalStorage localStorage, ISignatureService signatureService) {
    _providerService = httpProvider;
    _localStorage = localStorage;
    _signatureService = signatureService;
  }

  @override
  Future<String> initConnection(CloudConnectionCode code) async {
    var identity = await _signatureService.generatePrivateKey();
    var signature = await _signatureService.signMessage(identity, code.secret);
    var pk = await identity.extractPublicKey();
    var base64PublicKey = base64.encode(pk.bytes);
    var response = await _providerService.postRequest(
      HttpRequest(
        code.setupUrl,
        {},
        jsonEncode({
          "Email": "kristiformilchev@outlook.com",
          "PublicKey": base64PublicKey
        }),
      ),
    );

    if (response == null || response.statusCode != 200) {
      return "";
    }

    var currentConnections = await connections();
    if (currentConnections
            .firstWhereOrNull((element) => element.url == code.url) ==
        null) {
      currentConnections.add(code);
    }
    var json = currentConnections.map((e) => e.toJson());
    var encoded = jsonEncode(json);

    _localStorage.set("cloud-connections", encoded);
    return base64.encode(signature.bytes);
  }

  @override
  Future<bool> connect(CloudConnectionCode code, String signature) async {
    var result = await _providerService.postRequest(
      HttpRequest(
        code.setupUrl,
        {},
        jsonEncode(
          {"Signature": signature, "Uuid": code.id},
        ),
      ),
    );

    if (result == null || result.statusCode != 200) return false;
    return true;
  }

  @override
  Future<bool> disconnect(CloudConnectionCode code) async {
    var currentConnections = await connections();
    var filter =
        currentConnections.where((element) => element.id != code.id).toList();
    var json = filter.map((e) => e.toJson());
    var encoded = jsonEncode(json);

    _localStorage.set("cloud-connections", encoded);
    return true;
  }

  @override
  Future<List<CloudConnectionCode>> connections() async {
    var connections = await _localStorage.get("cloud-connections");
    if (connections == null) return [];

    var decoded = jsonDecode(connections);
    List<CloudConnectionCode> cloudData = [];
    for (var connection in decoded) {
      var cloudConnection = CloudConnectionCode.fromJson(connection);
      cloudData.add(cloudConnection);
    }

    return cloudData;
  }
}
