import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:infrastructure/interfaces/iconfiguration.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';

class Configuration implements IConfiguration {
  IlocalStorage storage;
  Configuration({required this.storage});

  @override
  late Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load() async {
    var existingOverride = await storage.get("Config");
    if (existingOverride != null) {
      var map = jsonDecode(existingOverride);
      return map;
    }

    final String jsonString = await rootBundle.loadString(
      'packages/domain/config.json',
    );
    data = json.decode(jsonString);
    return data;
  }

  @override
  Future<bool> overrideConfig() {
    // TODO: implement overrideConfig
    throw UnimplementedError();
  }
}
