import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:domain/models/device.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:domain/models/http_request.dart';
import 'package:domain/models/enums.dart';

class LocalNetworkService implements ILocalNetworkService {
  late IHttpProviderService _httpProviderService;

  LocalNetworkService(IHttpProviderService httpProviderService) {
    _httpProviderService = httpProviderService;
  }

  @override
  Future<Device> getNetworkData() async {
    var identifier = await getMacAddress();
    var name = await getDeviceName();
    var ip = await getIPAddress();
    var deviceType = getDeviceType();
    return Device(name, "", ip, "0000", identifier, deviceType, SyncTypes.otc);
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

      futures.add(_scanDevice(target, _devices));
    }

    var res = await Future.wait(futures);

    return res.where((element) => element != null).toList();
  }

  Future<Device?> _scanDevice(String target, List<Device> devices) async {
    final ping = await _httpProviderService.getRequest(
      HttpRequest("http://$target:9787/ping", {}, {}),
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
  }
}