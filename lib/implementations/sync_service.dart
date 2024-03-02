import 'dart:convert';
import 'package:cryptography/src/cryptography/simple_key_pair.dart';
import 'package:domain/models/device.dart';
import 'package:domain/models/enums.dart';
import 'package:domain/models/http_request.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:infrastructure/interfaces/iidentity_manager.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/iotp_service.dart';
import 'package:infrastructure/interfaces/isecret_manager.dart';
import 'package:infrastructure/interfaces/isession_service.dart';
import 'package:infrastructure/interfaces/isync_service.dart';

class SyncService implements ISyncService {
  late IlocalStorage _storage;
  late ISecretManager _secretManager;
  late IIdentityManager _identityManager;
  late IOtpService _otpService;
  late ISessionService _sessionService;
  late ILocalNetworkService _localNetworkService;
  late IHttpProviderService _httpProviderService;

  SyncService(
      IlocalStorage storage,
      ISecretManager secretManager,
      IIdentityManager identityManager,
      IOtpService otpService,
      ISessionService sessionService,
      ILocalNetworkService localNetworkService,
      IHttpProviderService providerService) {
    _storage = storage;
    _secretManager = secretManager;
    _identityManager = identityManager;
    _otpService = otpService;
    _sessionService = sessionService;
    _localNetworkService = localNetworkService;
    _httpProviderService = providerService;
  }

  @override
  oneTimeSync(String deviceId, data) {
    // TODO: implement oneTimeSync
    throw UnimplementedError();
  }

  @override
  setPatrialSyncOptions(String deviceId, List<String> secrets,
      List<String> identities, List<String> otpCodes) {
    // TODO: implement setPatrialSyncOptions
    throw UnimplementedError();
  }

  @override
  setSyncType(String deviceId, SyncTypes syncType) async {
    await _storage.set("$deviceId-Sync-Type", syncType.name);
  }

  @override
  Future<SyncTypes> getSyncType(String deviceId) async {
    var exists = await _storage.get("$deviceId-Sync-Type");
    if (exists == null) return SyncTypes.otc;

    switch (exists) {
      case "partial":
        return SyncTypes.partial;
      case "full":
        return SyncTypes.full;
      default:
        return SyncTypes.otc;
    }
  }

  @override
  synchronize(Device device) async {
    var type = await getSyncType(device.mac);
    switch (type) {
      case SyncTypes.full:
        performFullSync(device);
      case SyncTypes.partial:
      // TODO: Handle this case.
      case SyncTypes.otc:
      // TODO: Handle this case.
    }
  }

  performFullSync(Device device) async {
    var secrets = await _secretManager.getSecrets();
    var identities = await _identityManager.getSecrets();
    var otpSecrets = await _otpService.get();
    var data = {
      'secrets': secrets.map((e) => e.toJson()).toList(),
      'identities': identities.map((e) => e.toJson()).toList(),
      'otpSecrets': otpSecrets.map((e) => e.toJson()).toList()
    };

    var json = jsonEncode(data);
    var getSessionToken = await _sessionService.getToken(device);
    if (getSessionToken == null) {
      var challange = await _localNetworkService.requestChallange(device);
      var result =
          await _localNetworkService.connectToDevice(device, challange);
      if (!result) return;

      getSessionToken = await _sessionService.getToken(device);
    }

    var response = await _httpProviderService.postRequest(
      HttpRequest(
        "https://${device.ip}:${device.port}/sync",
        {"Authorization": "Bearer $getSessionToken"},
        json,
      ),
    );

    //TODO handle exceptions here.
    if (response == null || response.statusCode != 200) return;

    var genLogId = _storage.generateId();
    var credentials = await _localNetworkService.getCredentails(device);

    syncLog(device, genLogId, credentials);
  }

  void syncLog(
    Device device,
    Future<String> genLogId,
    SimpleKeyPair credentials,
  ) {
    //TODO add logs for saved sync events
  }
}
