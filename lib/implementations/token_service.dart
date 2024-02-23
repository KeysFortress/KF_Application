import 'dart:convert';
import 'package:cryptography/helpers.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:infrastructure/interfaces/iconfiguration.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:infrastructure/interfaces/ilocal_storage.dart';
import 'package:infrastructure/interfaces/itoken_service.dart';
import 'package:domain/models/app_config.dart';

class TokenService implements ITokenService {
  late String _secret;
  late AppConfig config;
  late String name;
  late IlocalStorage _localStorage;
  late ILocalNetworkService _localNetworkService;
  List<String> revokedTokens = [];

  TokenService(IConfiguration configuration, IlocalStorage storage,
      ILocalNetworkService networkService) {
    configuration.getConfig().then((value) => config = value).whenComplete(() {
      _secret = config.jtwSecret;
    });
    _localStorage = storage;
    storage.get("revokedTokens").then((value) {
      if (value == null) return;

      List<String> decode = jsonDecode(value);
      revokedTokens = decode;
    });
    _localNetworkService.getNetworkData().then((value) {
      name = value.name;
    });
  }

  @override
  String issueToken() {
    final jwt = JWT(
      subject: "Authenticaion Token",
      {
        'id': randomBytes(32).toString(),
        'server': {
          'id': name,
        }
      },
      issuer: 'KeyFortress',
    );

    final token = jwt.sign(
      SecretKey(_secret),
      algorithm: JWTAlgorithm.EdDSA,
      expiresIn: Duration(days: 10),
    );

    return token;
  }

  @override
  String renewToken(String token) {
    try {
      JWT.verify(token, SecretKey(_secret));
      var newToken = issueToken();
      return newToken;
    } on JWTExpiredException {
      print('jwt expired');
      return "";
    } on JWTException catch (ex) {
      print(ex.message);
      return "";
    }
  }

  @override
  bool revokeToken(String token) {
    try {
      revokedTokens.add(token);
      _localStorage.set("revokedTokens", jsonEncode(revokedTokens));
      return true;
    } catch (ex) {
      return false;
    }
  }

  @override
  bool validateToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secret));

      print('Payload: ${jwt.payload}');
      return true;
    } on JWTExpiredException {
      print('jwt expired');
      return false;
    } on JWTException catch (ex) {
      print(ex.message);
      return false;
    }
  }
}
