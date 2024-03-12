import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:domain/models/stored_secret.dart';
import 'package:flutter/services.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/isecret_manager.dart';

class SecretManger implements ISecretManager {
  final IlocalStorage localStorage;
  final String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  final String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final String digitChars = '0123456789';
  final String specialChars = r'!@#$%^&*()-_=+[]{}|;:,.<>?/';

  SecretManger({required this.localStorage});

  @override
  String generateSecret({
    int length = 12,
    bool isSecial = true,
    bool isUpper = true,
    bool isLower = true,
    bool isDigit = true,
    bool isUnique = true,
  }) {
    String allChars = "";

    if (isLower) allChars += lowercaseChars;
    if (isUpper) allChars += uppercaseChars;
    if (isDigit) allChars += digitChars;
    if (isSecial) allChars += specialChars;
    Random random = Random.secure();
    List<String> passwordCharacters = List.generate(
        length, (index) => allChars[random.nextInt(allChars.length)]);
    passwordCharacters.shuffle();

    return passwordCharacters.join();
  }

  @override
  Future<List<StoredSecret>> getSecrets() async {
    var secretsData = await localStorage.get("secrets");
    if (secretsData == null) return [];

    List<dynamic> data = jsonDecode(secretsData);
    List<StoredSecret> result = [];
    data.forEach((element) {
      var current = StoredSecret.fromJson(element);
      result.add(current);
    });

    return result;
  }

  @override
  Future<List<StoredSecret>> importSecrets(List<StoredSecret> secrets) async {
    List<StoredSecret> missing = [];

    var secretsData = await localStorage.get("secrets");
    List<dynamic> data = [];
    if (secretsData != null) data = jsonDecode(secretsData);

    List<StoredSecret> result = [];
    data.forEach((element) {
      var current = StoredSecret.fromJson(element);
      result.add(current);
    });

    missing = result
        .where((element) =>
            secrets.firstWhereOrNull((incomingSecret) =>
                incomingSecret.content == element.content) ==
            null)
        .toList();

    secrets
        .where((incomingSecret) =>
            result.firstWhereOrNull(
                (element) => element.content == incomingSecret.content) ==
            null)
        .toList()
        .forEach((element) {
      result.add(element);
    });

    var json = result.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await localStorage.set("secrets", jsonData);
    return missing;
  }

  @override
  Future<bool> setSecret(StoredSecret secret) async {
    var secretsData = await localStorage.get("secrets");
    if (secretsData == null) {
      List<StoredSecret> result = [];
      result.add(secret);
      var json = result.map((e) => e.toJson()).toList();
      var jsonData = jsonEncode(json);
      await localStorage.set("secrets", jsonData);
      return true;
    }

    List<dynamic> data = jsonDecode(secretsData);
    List<StoredSecret> result = [];
    data.forEach((element) {
      var current = StoredSecret.fromJson(element);
      result.add(current);
    });

    result.add(secret);
    var json = result.map((e) => e.toJson()).toList();
    var jsonData = jsonEncode(json);
    await localStorage.set("secrets", jsonData);

    return true;
  }

  @override
  Future<bool> copySensitiveData(String data) async {
    try {
      //TODO add a call to a popup notifying the user about the
      //danger in copying passwords as plain text

      await Clipboard.setData(
        ClipboardData(
          text: data,
        ),
      );

      Future.delayed(
        Duration(seconds: 20),
        () async {
          await Clipboard.setData(ClipboardData(text: ""));
        },
      );
      return true;
    } catch (ex) {
      //TODO add a dialog to show the user the action failed
      return false;
    }
  }
}
