import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';

class LocalStorage implements IlocalStorage {
  late FlutterSecureStorage _prefs;
  late IOSOptions _iosOptions;
  late AndroidOptions _androidOptions;
  late WindowsOptions _windowsOptions;
  late LinuxOptions _linuxOptions;
  late MacOsOptions _macOsOptions;
  LocalStorage() {
    _prefs = new FlutterSecureStorage();
    _iosOptions = IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    );
    _androidOptions = const AndroidOptions(
      encryptedSharedPreferences: true,
    );
    _windowsOptions = WindowsOptions();
    _linuxOptions = LinuxOptions();
    _macOsOptions = MacOsOptions.defaultOptions;
  }

  @override
  Future<dynamic> get(String key) async {
    try {
      return await _prefs.read(
        key: key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        lOptions: _linuxOptions,
        mOptions: _macOsOptions,
        wOptions: _windowsOptions,
      );
    } catch (ex) {
      //TODO add logging
      return null;
    }
  }

  @override
  Future<bool> remove(String key) async {
    try {
      await _prefs.delete(
        key: key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        lOptions: _linuxOptions,
        mOptions: _macOsOptions,
        wOptions: _windowsOptions,
      );
      return true;
    } catch (ex) {
      //TODO add loggin
      return false;
    }
  }

  @override
  Future<bool> set(String key, dynamic value) async {
    try {
      var isSet = false;
      if (value is String) {
        await _prefs.write(
          key: key,
          value: value,
          aOptions: _androidOptions,
          iOptions: _iosOptions,
          lOptions: _linuxOptions,
          mOptions: _macOsOptions,
          wOptions: _windowsOptions,
        );
        isSet = true;
      }

      return isSet;
    } catch (ex) {
      //TODO add Logging in case of an exception
      return false;
    }
  }

  @override
  Future<String> generateId() async {
    var random = Random.secure();
    var id = List<int>.generate(8, (index) => random.nextInt(256));
    var idBytes = base64.encode(Uint8List.fromList(id));

    var exists = await get(idBytes);
    while (exists != null) {
      idBytes = base64.encode(Uint8List.fromList(id));
      exists = await get(idBytes);
    }

    await set("systemId", idBytes);
    return idBytes;
  }
}
