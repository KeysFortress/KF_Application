import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:domain/models/device.dart';
import 'package:flutter/foundation.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:domain/models/http_request.dart';
import 'package:domain/models/enums.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:domain/converters/binary_converter.dart';

class LocalNetworkService implements ILocalNetworkService {
  late IHttpProviderService _httpProviderService;
  late ISignatureService _signatureService;
  late IlocalStorage _storage;

  LocalNetworkService(IHttpProviderService httpProviderService,
      ISignatureService signatureService, IlocalStorage storage) {
    _httpProviderService = httpProviderService;
    _signatureService = signatureService;
    _storage = storage;
  }

  @override
  Future<Device> getNetworkData() async {
    var identifier = await getMacAddress();
    var name = await getDeviceName();
    var ip = await getIPAddress();
    var deviceType = getDeviceType();
    return Device(name, "", ip, "9787", identifier, deviceType, SyncTypes.otc);
  }

  DeviceTypes getDeviceType() {
    var identifier = DeviceTypes.mobile;

    if (Platform.isAndroid) {
      identifier = DeviceTypes.mobile;
    }

    if (Platform.isIOS) {
      identifier = DeviceTypes.mobile;
    }

    if (Platform.isLinux) {
      identifier = DeviceTypes.desktop;
    }

    if (Platform.isMacOS) {
      identifier = DeviceTypes.desktop;
    }

    if (Platform.isWindows) {
      identifier = DeviceTypes.desktop;
    }

    return identifier;
  }

  Future<String> getIPAddress() async {
    return await NetworkInterface.list()
        .then((List<NetworkInterface> interfaces) {
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
      return 'Unknown';
    });
  }

  Future<String> getMacAddress() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    var identifier = "";

    if (Platform.isAndroid) {
      var info = await deviceInfo.androidInfo;
      identifier = info.display;
    }

    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      identifier = info.name;
    }

    if (Platform.isLinux) {
      var info = await deviceInfo.linuxInfo;
      identifier = info.id;
    }

    if (Platform.isMacOS) {
      var info = await deviceInfo.macOsInfo;
      identifier = info.systemGUID.toString();
    }

    if (Platform.isWindows) {
      var info = await deviceInfo.windowsInfo;
      identifier = info.deviceId.toString();
    }

    return identifier;
  }

  Future<String> getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    var identifier = "";

    if (Platform.isAndroid) {
      var info = await deviceInfo.androidInfo;
      identifier = info.display;
    }

    if (Platform.isIOS) {
      var info = await deviceInfo.iosInfo;
      identifier = info.name;
    }

    if (Platform.isLinux) {
      var info = await deviceInfo.linuxInfo;
      identifier = info.name;
    }

    if (Platform.isMacOS) {
      var info = await deviceInfo.macOsInfo;
      identifier = info.computerName;
    }

    if (Platform.isWindows) {
      var info = await deviceInfo.windowsInfo;
      identifier = info.computerName;
    }

    return identifier;
  }

  Future<List<Device?>> scan() async {
    final baseIp = '192.168.1.';
    List<Device> _devices = [];

    final List<Future<Device?>> futures = [];

    for (int i = 1; i <= 255; i++) {
      final target = baseIp + i.toString();

      futures.add(scanDevice(target, _devices));
    }

    var res = await Future.wait(futures);

    return res.where((element) => element != null).toList();
  }

  Future<Device?> scanDevice(String target, List<Device> devices) async {
    final ping = await _httpProviderService.getRequest(
      HttpRequest("https://$target:9787/ping", {}, {}),
      timeout: 1,
    );
    if (ping == null || ping.statusCode != 200) {
    } else {
      print("Connected");

      try {
        var data = jsonDecode(ping.body);
        return Device.fromJson(data);
      } catch (ex) {
        print("Bad Response, data doesn't match the device model");
        return null;
      }
    }
    return null;
  }

  @override
  Future<SimpleKeyPair> getCredentails(Device device) async {
    var encryptionKey = await _storage.get(
      "${device.mac}-communication-key-public-store",
    );
    var encryptionKeyPrivate = await _storage.get(
      "${device.mac}-communication-key-private-store",
    );
    return encryptionKey != null && encryptionKeyPrivate != null
        ? await constructFromStorage(encryptionKey, encryptionKeyPrivate)
        : await generateNewKey(device);
  }

  Future<SimpleKeyPair> constructFromStorage(
      encryptionKey, encryptionKeyPrivate) async {
    return await _signatureService.importKeyPair(
        encryptionKey, encryptionKeyPrivate);
  }

  Future<SimpleKeyPair> generateNewKey(Device device) async {
    var keys = await _signatureService.generatePrivateKey();
    var publicKey = await keys.extractPublicKey();
    var privateKey = await keys.extractPrivateKeyBytes();

    var publicKeyData = BianaryConverter.toHex(publicKey.bytes);
    var privateKeyData = BianaryConverter.toHex(privateKey);

    _storage.set("${device.mac}-communication-key-public-store", publicKeyData);
    _storage.set(
        "${device.mac}-communication-key-private-store", privateKeyData);

    return keys;
  }

  Future<bool> connectToDevice(Device device, String challange) async {
    SimpleKeyPair credentials = await getCredentails(device);
    var sign = await _signatureService.signMessage(credentials, challange);
    var publicKey = await credentials.extractPublicKey();

    print(await credentials.extractPublicKey());
    var serialize = jsonEncode({
      "signature": BianaryConverter.toHex(sign.bytes),
      "publicKey": BianaryConverter.toHex(publicKey.bytes),
      "challange": challange
    });

    var publicKeyFromSign = (sign.publicKey as SimplePublicKey).bytes;

    if (listEquals(publicKeyFromSign, publicKey.bytes)) {
      print('Public keys match!');
    } else {
      print('Public keys do not match.');
    }

    print('Public Key from Sign: $publicKeyFromSign');
    print('Public Key from Credentials: ${publicKey.bytes}');
    var result = await _httpProviderService.postRequest(
      HttpRequest(
        "https://${device.ip}:${device.port}/pair",
        {},
        serialize,
      ),
    );

    if (result == null || result.statusCode != 200) return false;

    //TODO save the data to the session
    print("ok");
    return true;
  }

  @override
  Future<String> requestChallange(Device device) async {
    SimpleKeyPair keys = await getCredentails(device);
    var publicData = await keys.extractPublicKey();
    var hex = BianaryConverter.toHex(publicData.bytes);
    final challangeResponse = await _httpProviderService.postRequest(
      HttpRequest(
        "https://${device.ip}:${device.port}/request-pair",
        {},
        hex,
      ),
    );

    if (challangeResponse == null || challangeResponse.statusCode != 200)
      throw Exception("Failed to receive a sign in challange");

    return challangeResponse.body;
  }
}
