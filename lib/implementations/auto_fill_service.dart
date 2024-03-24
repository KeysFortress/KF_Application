import 'package:infrastructure/interfaces/iautofill_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';

class AutoFillService implements IAutoFillService {
  late IlocalStorage _localStorage;

  AutoFillService(IlocalStorage localStorage) {
    _localStorage = localStorage;
  }

  @override
  enableAutoFill(bool state) async {
    try {
      await _localStorage.set("enable_auto_fill", state ? "1" : "0");
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  enabledPasskeyAutoFill(bool state) async {
    try {
      await _localStorage.set("enable_passkey_auto_fill", state ? "1" : "0");
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  isAutoFillEnabled() async {
    try {
      var enabled = await _localStorage.get("enable_auto_fill");
      if (enabled == null) return false;

      return enabled == "1";
    } catch (ex) {
      return false;
    }
  }

  @override
  isPasskeyAutoFillEnabled() async {
    try {
      var enabled = await _localStorage.get("enable_passkey_auto_fill");
      if (enabled == null) return false;

      return enabled == "1";
    } catch (ex) {
      return false;
    }
  }
}
