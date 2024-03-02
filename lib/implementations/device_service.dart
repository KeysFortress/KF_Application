import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:domain/models/device.dart';
import 'package:domain/models/http_request.dart';
import 'package:infrastructure/interfaces/idevices_service.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';

class DeviceService implements IDevicesService {
  late IlocalStorage _storage;
  late IHttpProviderService _providerService;

  DeviceService(
      IlocalStorage storage, IHttpProviderService httpProviderService) {
    _storage = storage;
    _providerService = httpProviderService;
  }

  @override
  Future<bool> add(Device device) async {
    List<Device> devices = [];
    var deviceData = await _storage.get("devices");

    if (deviceData != null) {
      List<dynamic> data = jsonDecode(deviceData);
      data.forEach((element) {
        var current = Device.fromJson(element);
        devices.add(current);
      });
    }
    if (devices.firstWhereOrNull((element) => element.mac == device.mac) !=
        null) return false;

    devices.add(device);
    var json = devices.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await _storage.set("devices", jsonData);

    return true;
  }

  @override
  Future<List<Device>> all() async {
    List<Device> devices = [];
    var deviceData = await _storage.get("devices");

    if (deviceData == null) return [];
    List<dynamic> data = jsonDecode(deviceData);
    data.forEach((element) {
      var current = Device.fromJson(element);
      devices.add(current);
    });
    return devices;
  }

  @override
  Future<bool> remove(Device device) async {
    List<Device> devices = [];
    var deviceData = await _storage.get("devices");

    if (deviceData != null) {
      List<dynamic> data = jsonDecode(deviceData);
      data.forEach((element) {
        var current = Device.fromJson(element);
        devices.add(current);
      });
    }

    devices.removeWhere(
      (element) => element.name == device.name && element.mac == device.mac,
    );

    var json = devices.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await _storage.set("devices", jsonData);

    return true;
  }

  @override
  Future<bool> isDeviceConnected(Device current) async {
    var response = await _providerService.getRequest(
      HttpRequest(
        "https://${current.ip}:${current.port}/status",
        {},
        {},
      ),
    );

    if (response == null || response.statusCode != 200) return false;

    return true;
  }
}
