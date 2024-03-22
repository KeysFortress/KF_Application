import 'dart:convert';
import 'package:domain/models/device_sync_event.dart';
import 'package:domain/models/exchanged_data.dart';
import 'package:domain/models/device.dart';
import 'package:domain/models/selectable_exchange_data.dart';
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
  Future<SelectableExchangeData> getPartialData(String deviceId) async {
    var partialDataSecrets = await _storage.get("$deviceId-sync-secrets");
    List<dynamic> partialDataSecretsItems = [];
    if (partialDataSecrets != null)
      partialDataSecretsItems = jsonDecode(partialDataSecrets);

    var partialDataIdentities = await _storage.get("$deviceId-sync-identities");
    List<dynamic> partialDataIdentitiesItems = [];
    if (partialDataIdentities != null)
      partialDataIdentitiesItems = jsonDecode(partialDataIdentities);

    var partialDataOtpCodes = await _storage.get("$deviceId-sync-otpCodes");
    List<dynamic> partialDataOtpCodesItems = [];
    if (partialDataOtpCodes != null)
      partialDataOtpCodesItems = jsonDecode(partialDataOtpCodes);

    var secrets = await _secretManager.getSecrets();
    var identities = await _identityManager.getSecrets();
    var otpCodes = await _otpService.get();

    var matchingSecrets = secrets
        .where(
          (element) =>
              partialDataSecretsItems.any((stored) => stored == element.id),
        )
        .toList();
    var matchingIdentities = identities
        .where(
          (element) =>
              partialDataIdentitiesItems.any((stored) => stored == element.id),
        )
        .toList();
    var matchingOtpCodes = otpCodes
        .where(
          (element) =>
              partialDataOtpCodesItems.any((stored) => stored == element.id),
        )
        .toList();

    return SelectableExchangeData(
      matchingSecrets,
      matchingIdentities,
      matchingOtpCodes,
    );
  }

  @override
  setPatrialSyncOptions(String deviceId, List<String> secrets,
      List<String> identities, List<String> otpCodes) async {
    var partialDataSecrets = await _storage.get("$deviceId-sync-secrets");
    List<dynamic> partialDataSecretsItems = [];
    if (partialDataSecrets != null)
      partialDataSecretsItems = jsonDecode(partialDataSecrets);

    var partialDataIdentities = await _storage.get("$deviceId-sync-identities");
    List<dynamic> partialDataIdentitiesItems = [];
    if (partialDataIdentities != null)
      partialDataIdentitiesItems = jsonDecode(partialDataIdentities);

    var partialDataOtpCodes = await _storage.get("$deviceId-sync-otpCodes");
    List<dynamic> partialDataOtpCodesItems = [];
    if (partialDataOtpCodes != null)
      partialDataOtpCodesItems = jsonDecode(partialDataOtpCodes);

    partialDataSecretsItems = secrets;
    partialDataIdentitiesItems = identities;
    partialDataOtpCodesItems = otpCodes;

    var secretsJsonData = jsonEncode(partialDataSecretsItems);
    await _storage.set("$deviceId-sync-secrets", secretsJsonData);

    var identitiesItemsJsonData = jsonEncode(partialDataIdentitiesItems);
    await _storage.set("$deviceId-sync-identities", identitiesItemsJsonData);

    var dataOtpCodesItemsJsonData = jsonEncode(partialDataOtpCodesItems);
    await _storage.set("$deviceId-sync-otpCodes", dataOtpCodesItemsJsonData);
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
        performPartialSync(device);
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
      DeviceSyncEvent(genLogId, device.ip, DateTime.now(), exchangeData, 1),
    );
  }

  performPartialSync(Device device) async {
    var syncData = await getPartialData(device.mac);
    var localNetworkData = await _localNetworkService.getNetworkData();

    var data = {
      'id': localNetworkData.mac,
      'secrets': syncData.secrets.map((e) => e.toJson()).toList(),
      'identities': syncData.identities.map((e) => e.toJson()).toList(),
      'otpSecrets': syncData.otpCodes.map((e) => e.toJson()).toList()
    };

    var json = jsonEncode(data);
    var token = await getSessionToken(device);

    var response = await _httpProviderService.postRequest(
      HttpRequest(
        "https://${device.ip}:${device.port}/sync-partial",
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
      DeviceSyncEvent(genLogId, device.ip, DateTime.now(), exchangeData, 2),
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

    var genLogId = await _storage.generateId();

    syncLog(
      device,
      DeviceSyncEvent(
        genLogId,
        device.ip,
        DateTime.now(),
        [],
        3,
      ),
    );
  }

  @override
  Future<List<DeviceSyncEvent>> getSyncLog(String mac) async {
    try {
      var logData = await _storage.get("$mac-sync-logs");
      if (logData == null) return [];

      List<dynamic> decoded = jsonDecode(logData);
      return decoded.map((e) => DeviceSyncEvent.fromJson(e)).toList();
    } catch (ex) {
      return [];
    }
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

  @override
  Future<bool> setServiceState(bool value) async {
    try {
      await _storage.set("global-sync-enabled", value ? "1" : "0");

      await setSyncOnAction(value);
      await setPasswordAction(value);
      await setIdentityAction(value);
      await setSecretAction(value);
      await setRacAction(value);
      await setRlcAction(value);
      await setTotpAction(value);
      await onConnectionAction(value);

      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setSyncOnAction(bool value) async {
    try {
      await _storage.set("global-sync-on-action-enabled", value ? "1" : "0");
      await setPasswordAction(value);
      await setIdentityAction(value);
      await setSecretAction(value);
      await setRacAction(value);
      await setRlcAction(value);
      await setTotpAction(value);
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setPasswordAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-password-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setIdentityAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-identity-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setSecretAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-secret-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setRacAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-rac-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setRlcAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-rlc-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setTotpAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-totp-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> onConnectionAction(bool value) async {
    try {
      await _storage.set(
          "global-sync-on-connection-action-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> setTimeBasedSyncAction(bool value) async {
    try {
      await _storage.set("global-time-based-sync-enabled", value ? "1" : "0");
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<bool> updateTimeToSync(int syncTime) async {
    try {
      await _storage.set("global-sync-time-threshold", syncTime);
      return true;
    } catch (ex) {
      //TODO add logging
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getGlobalSettings() async {
    var updateTime = await _storage.get("global-sync-time-threshold");
    var timeBasedSyncEnabled =
        await _storage.get("global-time-based-sync-enabled");
    var onConnectionAction =
        await _storage.get("global-sync-on-connection-action-enabled");
    var onTotpAction = await _storage.get("global-sync-on-totp-action-enabled");
    var onRlcAction = await _storage.get("global-sync-on-rlc-action-enabled");
    var onRacAction = await _storage.get("global-sync-on-rac-action-enabled");
    var onSecretAction =
        await _storage.get("global-sync-on-secret-action-enabled");
    var onIdentityAction =
        await _storage.get("global-sync-on-identity-action-enabled");
    var onPasswordAction = await _storage.get("global-sync-on-action-enabled");
    var enabled = await _storage.get("global-sync-enabled");
    var onAction = await _storage.get("global-sync-on-action-enabled");

    return {
      'updateTime': updateTime != null ? int.parse(updateTime) : 60,
      'timeBasedSync': timeBasedSyncEnabled != null
          ? timeBasedSyncEnabled == "1"
              ? true
              : false
          : true,
      'onConnection': onConnectionAction != null
          ? onConnectionAction == "1"
              ? true
              : false
          : true,
      'onTotp': onTotpAction != null
          ? onTotpAction == "1"
              ? true
              : false
          : true,
      'onRlc': onRlcAction != null
          ? onRlcAction == "1"
              ? true
              : false
          : true,
      'onRac': onRacAction != null
          ? onRacAction == "1"
              ? true
              : false
          : true,
      'onSecret': onSecretAction != null
          ? onSecretAction == "1"
              ? true
              : false
          : true,
      'onIdentity': onIdentityAction != null
          ? onIdentityAction == "1"
              ? true
              : false
          : true,
      'onPassword': onPasswordAction != null
          ? onPasswordAction == "1"
              ? true
              : false
          : true,
      'enabled': enabled != null
          ? enabled == "1"
              ? true
              : false
          : true,
      'onAction': onAction != null
          ? onAction == "1"
              ? true
              : false
          : true,
    };
  }
}
