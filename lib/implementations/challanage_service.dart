import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:infrastructure/interfaces/ichallanage_service.dart';
import 'package:domain/models/challange.dart';

class ChallangeService implements IChallangeService {
  List<Challange> _challanges = [];

  ChallangeService() {
    _challanges = [];
    Timer.periodic(Duration(seconds: 1), (timer) => checkExpiredChallanges());
  }

  @override
  String getChallange(String publicKey) {
    var current = _challanges.lastWhereOrNull(
      (element) => element.publicKey == publicKey,
    );

    if (current == null) throw Exception();

    return current.challange;
  }

  @override
  String issue(String publicKey) {
    var random = Random.secure();
    var challengeBytes = List<int>.generate(32, (index) => random.nextInt(256));
    var challenge = base64Url.encode(Uint8List.fromList(challengeBytes));

    _challanges.add(
      Challange(
        publicKey: publicKey,
        challange: challenge,
        expiresAt: DateTime.now().add(
          Duration(minutes: 5),
        ),
      ),
    );

    return challenge;
  }

  @override
  bool removeChallange(String pulicKey) {
    try {
      _challanges.removeWhere((element) => element.publicKey == pulicKey);
      return true;
    } catch (ex) {
      return false;
    }
  }

  checkExpiredChallanges() {
    _challanges.removeWhere(
      (element) => element.expiresAt.isBefore(
        DateTime.now(),
      ),
    );
  }
}
