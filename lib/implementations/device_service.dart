import 'dart:convert';

import 'package:domain/models/device.dart';
import 'package:infrastructure/interfaces/idevices_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';

class DeviceService implements IDevicesService {
  late IlocalStorage _storage;

  DeviceService(IlocalStorage storage) {
    _storage = storage;
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
}
