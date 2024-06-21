import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
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

  Future<CloudConnectionCode?> begin(String setupUrl) async {
    var identity = await getOrCreateIdentity();
    var publicKeyData = await identity.extractPublicKey();
    var publicKeyBase64 = base64.encode(publicKeyData.bytes);
    var request = await _providerService.postRequest(
      isAuthenticated: false,
      HttpRequest(
        setupUrl,
        {},
        jsonEncode({
          "Email": "kristiformilchev@outlook.com",
          "Base64Pk": publicKeyBase64,
        }),
      ),
    );

    if (request == null || request.statusCode != 200) return null;

    var json = jsonDecode(request.body);

    return CloudConnectionCode.fromJson(json);
  }

  @override
  Future<String> initConnection(CloudConnectionCode code) async {
    var identity = await getOrCreateIdentity();
    var signature = await _signatureService.signMessage(identity, code.secret);

    var currentConnections = await connections();
    if (currentConnections
            .firstWhereOrNull((element) => element.url == code.url) ==
        null) {
      currentConnections.add(code);
    }
    var json = currentConnections.map((e) => e.toJson()).toList();
    var encoded = jsonEncode(json);

    _localStorage.set("cloud-connections", encoded);
    return base64.encode(signature.bytes);
  }

  @override
  Future<bool> connect(
      CloudConnectionCode code, String signature, String deviceName) async {
    int deviceTypeId = getDeviceTypeId();
    if (deviceTypeId == -1) throw Exception("Platform not supported");

    var result = await _providerService.postRequest(
      HttpRequest(
        code.setupUrl,
        {},
        jsonEncode(
          {
            "Signature": signature,
            "Uuid": code.id,
            "DeviceName": deviceName,
            "DeviceType": deviceTypeId
          },
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

  Future<SimpleKeyPair> getOrCreateIdentity() async {
    var identity = await _localStorage.get("cloud-connection-identity");
    if (identity == null) return createIdenitity();

    var identityData = jsonDecode(identity);

    return await _signatureService.importKeyPair(
      identityData["publicKey"],
      identityData["privateKey"],
    );
  }

  Future<SimpleKeyPair> createIdenitity() async {
    var identity = await _signatureService.generatePrivateKey();
    var publicKey = await identity.extractPublicKey();
    var privateKey = await identity.extractPrivateKeyBytes();
    var base64PublicKey = base64.encode(publicKey.bytes);
    var base64PrivateKey = base64.encode(privateKey);

    await _localStorage.set(
      "cloud-connection-identity",
      jsonEncode(
        {
          "publicKey": base64PublicKey,
          "privateKey": base64PrivateKey,
        },
      ),
    );

    return identity;
  }

  int getDeviceTypeId() {
    if (Platform.isAndroid) return 1;
    if (Platform.isIOS) return 2;
    if (Platform.isWindows) return 3;
    if (Platform.isLinux) return 4;
    if (Platform.isMacOS) return 5;

    return -1;
  }

  Future<bool> login(CloudConnectionCode data) async {
    var getCredentials = await getOrCreateIdentity();
    var challangeData = await getChallange(data);

    var json = jsonDecode(challangeData);

    var code = json["Code"];
    var uuid = json["Uuid"];

    var signature = _signatureService.signMessage(getCredentials, code);

    var response = await _providerService.postRequest(
      HttpRequest(
        "${data.url}/finish-reques",
        {},
        jsonEncode(
          {
            "Signature": signature,
            "Uuid": uuid,
          },
        ),
      ),
    );

    if (response == null || response.statusCode != 200) return false;

    await _localStorage.set("${data.url}-mfa", response.body);
    return true;
  }

  @override
  Future<String> getBearer(CloudConnectionCode token) async {
    var authToken = await _localStorage.get("bearer-${token.url}");
    if (authToken == null) return "";

    return authToken;
  }

  @override
  Future<bool> performMethod(String code, CloudConnectionCode data) async {
    var mfaToken = await _localStorage.get("${data.url}-mfa");
    if (mfaToken == null) return false;

    var response = await _providerService.postRequest(
      isAuthenticated: false,
      HttpRequest(
        "${data.url}/mfa/perform-method",
        {"Authorization": "Bearer $mfaToken"},
        jsonEncode(
          {
            "Code": code,
          },
        ),
      ),
    );

    if (response == null || response.statusCode != 200) return false;

    _localStorage.set("bearer-${data.url}", response.body);
    return true;
  }

  Future<String> getChallange(CloudConnectionCode data) async {
    var response = await _providerService.getRequest(
      HttpRequest(
        "${data.url}/begin-request/kristiformilchev@outlook.com",
        {},
        {},
      ),
    );

    if (response == null || response.statusCode != 200) return "";

    return response.body;
  }
}
