import 'package:collection/collection.dart';
import 'package:domain/models/enums.dart';
import 'package:infrastructure/interfaces/iauthorization_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/iotp_service.dart';

class AutherizationService implements IAuthorizationService {
  late IOtpService _otpService;
  late IlocalStorage _localStorage;
  AutherizationService(IOtpService otpService, IlocalStorage storage) {
    _otpService = otpService;
    _localStorage = storage;
  }

  @override
  Future<DeviceLockType> getDeviceLockType() async {
    var lockType = await _localStorage.get("lock_type");
    if (lockType == null) return DeviceLockType.none;
    var lock = DeviceLockType.values
        .firstWhereOrNull((element) => element.name == lockType);
    return lock ?? DeviceLockType.none;
  }

  @override
  Future<bool> isDeviceLocked() async {
    var isLocked = await _localStorage.get("locked");
    if (isLocked == null) return false;

    return isLocked == "closed" ? true : false;
  }

  @override
  Future<bool> setDeviceLockType(DeviceLockType type, {String? value}) async {
    try {
      await _localStorage.set("lock_type", type.name);
      if (value != null) {
        await _localStorage.set("lock_value", value);
      }
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> unlockPin(String value) async {
    var val = await _localStorage.get("lock_value");
    if (val == null) return false;

    return val == value;
  }

  @override
  Future<bool> unlockTotp(String code) async {
    var val = await _localStorage.get("lock_value");
    if (val == null) return false;

    var validCode = _otpService.getCode(val);
    return validCode == code;
  }

  @override
  Future<bool> enableBiometric() async {
    try {
      await _localStorage.set("lock_type", DeviceLockType.biometric.name);
      return true;
    } catch (ex) {
      return false;
    }
  }
}
