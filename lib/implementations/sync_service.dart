import 'dart:convert';
import 'package:domain/models/device_sync_event.dart';
import 'package:domain/models/exchanged_data.dart';
import 'package:domain/models/device.dart';
import 'package:domain/models/stored_identity.dart';
import 'package:domain/models/stored_secret.dart';
import 'package:domain/models/otp_code.dart';
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
        break;
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
    var token = await getSessionToken(device);

    var response = await _httpProviderService.postRequest(
      HttpRequest(
        "https://${device.ip}:${device.port}/sync",
        {"Authorization": "Bearer $token"},
        json,
      ),
    );

    //TODO handle exceptions here.
    if (response == null || response.statusCode != 200) return;

    var genLogId = await _storage.generateId();
    var decoded = jsonDecode(response.body);

    List<dynamic> identitiesMissingData = decoded["identities"];
    List<dynamic> secretsMissingData = decoded["secrets"];
    List<dynamic> otpMissingData = decoded["otpSecrets"];

    List<ExchangedData> exchangeData = [];
    var exchangedIdentities = identitiesMissingData.map(
      (e) {
        var item = StoredIdentity.fromJson(e);
        exchangeData.add(ExchangedData(item.name, 1, true));
        return item;
      },
    ).toList();
    var exchangedSecrets = secretsMissingData.map(
      (e) {
        var secret = StoredSecret.fromJson(e);
        exchangeData.add(ExchangedData(secret.name, 2, true));
        return secret;
      },
    ).toList();
    var exchangedOtp = otpMissingData.map(
      (e) {
        var otp = OtpCode.fromJson(e);
        exchangeData.add(
          ExchangedData("${otp.address} - ${otp.issuer}", 3, true),
        );
        return otp;
      },
    ).toList();

    await _identityManager.importSecrets(exchangedIdentities);
    await _secretManager.importSecrets(exchangedSecrets);
    await _otpService.importCodes(exchangedOtp);

    await syncLog(
      device,
      DeviceSyncEvent(genLogId, device.ip, DateTime.now(), exchangeData),
    );
  }

  @override
  oneTimeSync(Device device, data) async {
    var token = await getSessionToken(device);

    var response = await _httpProviderService.postRequest(
      HttpRequest(
        "https://${device.ip}:${device.port}/one-time-connection",
        {"Authorization": "Bearer $token"},
        data,
      ),
    );

    //TODO handle exceptions here.
    if (response == null || response.statusCode != 200) return;
  }

  Future<String?> getSessionToken(Device device) async {
    var getSessionToken = await _sessionService.getToken(device);
    if (getSessionToken == null) {
      var challange = await _localNetworkService.requestChallange(device);
      var result =
          await _localNetworkService.connectToDevice(device, challange);
      if (!result) return null;

      return await _sessionService.getToken(device);
    }

    return getSessionToken;
  }

  syncLog(
    Device device,
    DeviceSyncEvent event,
  ) async {
    var tryParse = event.toJson();
    print(tryParse);

    var logData = await _storage.get("${device.mac}-sync-logs");
    List<dynamic> data = [];
    if (logData != null) data = jsonDecode(logData);

    var syncData = data.map((e) => DeviceSyncEvent.fromJson(e)).toList();
    syncData.add(event);
    var json = syncData.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await _storage.set("${device.mac}-sync-logs", jsonData);
  }
}
