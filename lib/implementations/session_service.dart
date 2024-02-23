import 'package:domain/models/device.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/isession_service.dart';

class SessionService implements ISessionService {
  late IlocalStorage _storage;

  SessionService(IlocalStorage localStorage) {
    _storage = localStorage;
  }

  @override
  Future add(String token, Device device) async {
    await _storage.set("${device.name}_${device.mac}", token);
  }

  @override
  Future<String?> getToken(Device device) async {
    return await _storage.get("${device.name}_${device.mac}");
  }

  @override
  Future remove(Device device) async {
    await _storage.set("${device.name}_${device.mac}", "");
  }
}
