import 'package:collection/collection.dart';
import 'package:domain/models/enums.dart';
import 'package:infrastructure/interfaces/iauthorization_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/iotp_service.dart';

class AutherizationService implements IAuthorizationService {
  late IOtpService _otpService;
  late IlocalStorage _localStorage;
  bool _ignoreLock = false;
  @override
  bool get ignoreLock => ignoreLock;

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

    var validCode = _otpService.getCode(val, 30);
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

  @override
  Future<bool> unlockPattern(List<int> input) async {
    var val = await _localStorage.get("lock_value");
    if (val == null) return false;

    var convertToString = "";

    input.forEach((e) {
      convertToString += "$e,";
    });
    convertToString = convertToString.substring(0, convertToString.length - 1);

    return val == convertToString;
  }

  @override
  Future<int> getTimeLockTime() async {
    var val = await _localStorage.get("lock_time");
    if (val == null) return 60;

    return int.parse(val);
  }

  @override
  Future<bool> isMinimizeLockEnabled() async {
    var val = await _localStorage.get("lock_minimize");
    if (val == null) return true;

    return val == "1";
  }

  @override
  Future<bool> setMinimizeLockEnabled(bool state) async {
    try {
      await _localStorage.set("lock_minimize", state ? "1" : "0");
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> isTimeLockEnabled() async {
    var val = await _localStorage.get("lock_time_enabled");
    if (val == null) return true;

    return val == "1";
  }

  @override
  Future<bool> setLockTimeEnabled(bool state) async {
    try {
      await _localStorage.set("lock_time_enabled", state ? "1" : "0");
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> setLockTime(int lockTime) async {
    try {
      await _localStorage.set("lock_time", lockTime.toString());
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> isDeviceLockEnabled() async {
    var val = await _localStorage.get("lock_enabled");
    if (val == null) return true;

    return val == "1";
  }

  @override
  Future<bool> setDeviceLockEnabled(bool state) async {
    try {
      await _localStorage.set("lock_enabled", state ? "1" : "0");
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> setSelfDestructAttempts(int totalAttempts) async {
    try {
      await _localStorage.set("unlock_attempts", totalAttempts.toString());
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<int> getSelfDestructAttemts() async {
    var val = await _localStorage.get("unlock_attempts");
    if (val == null) return 3;

    return int.parse(val);
  }

  @override
  Future<bool> setSelfDestructState(bool value) async {
    try {
      await _localStorage.set("self_destruct", value ? "1" : "0");
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  Future<bool> selfDestructActivated() async {
    var val = await _localStorage.get("self_destruct");
    if (val == null) return false;

    return val == "1";
  }

  @override
  bool setIgnoreState() {
    _ignoreLock = true;
    return true;
  }

  @override
  bool cancelIgnoreLockState() {
    _ignoreLock = false;
    return true;
  }
}
