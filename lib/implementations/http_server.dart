import 'dart:convert';
import 'dart:io' as dio;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:infrastructure/interfaces/ichallanage_service.dart';
import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:infrastructure/interfaces/iidentity_manager.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:infrastructure/interfaces/iotp_service.dart';
import 'package:infrastructure/interfaces/isecret_manager.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:infrastructure/interfaces/isync_service.dart';
import 'package:infrastructure/interfaces/itoken_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:domain/converters/binary_converter.dart';
import 'package:domain/models/stored_identity.dart';
import 'package:domain/models/stored_secret.dart';
import 'package:domain/models/otp_code.dart';
import 'package:domain/models/enums.dart';

class HttpServer implements IHttpServer {
  late ILocalNetworkService _localNetworkService;
  late ISignatureService _signatureService;
  late IChallangeService _challangeService;
  late ITokenService _tokenService;
  late ISecretManager _secretManager;
  late IIdentityManager _identityManager;
  late IOtpService _otpService;
  late ISyncService _syncService;

  dio.HttpServer? _server;
  late Router _app;

  HttpServer(
      ILocalNetworkService localNetworkService,
      ISignatureService signatureService,
      IChallangeService challangeService,
      ITokenService tokenService,
      ISecretManager secretManager,
      IIdentityManager identityManager,
      IOtpService otpService,
      ISyncService syncService) {
    _localNetworkService = localNetworkService;
    _signatureService = signatureService;
    _challangeService = challangeService;
    _tokenService = tokenService;

    _secretManager = secretManager;
    _identityManager = identityManager;
    _otpService = otpService;
    _syncService = syncService;
  }

  @override
  Future restartServer() async {
    await _server?.close(force: true);
    await startServer();
  }

  @override
  Future startServer() async {
    final certPath = 'lib/certificates/cert.pem';
    final keyPath = 'lib/certificates/key.pem';

    final certData = await rootBundle.load(certPath);
    final keyData = await rootBundle.load(keyPath);

    _app = Router();

    _app.get("/ping", (Request request) async {
      print("Incoming request");
      var device = await _localNetworkService.getNetworkData();

      return Response.ok(
        jsonEncode(
          device,
        ),
      );
    });

    _app.get("/status", (Request request) async {
      return Response.ok("200");
    });

    _app.post('/request-pair', (Request request) async {
      var key = await request.readAsString();
      var challange = _challangeService.issue(key);
      return Response.ok(challange);
    });

    _app.get('/login/<key>', (Request request, String key) {
      return Response.ok('hello-world $key');
    });

    _app.post('/pair', (Request request) async {
      final signatureData = await request.readAsString();
      var json = jsonDecode(signatureData);
      var challange = _challangeService.getChallange(json["publicKey"]);
      var sigData = BianaryConverter.hexStringToList(json['signature']);
      var pkBytes = BianaryConverter.hexStringToList(json["publicKey"]);

      var isAuthentinicationValid = await _signatureService.verifySignature(
        BianaryConverter.hexStringToList(challange),
        Signature(
          sigData,
          publicKey: SimplePublicKey(
            pkBytes,
            type: KeyPairType.ed25519,
          ),
        ),
      );
      var token = _tokenService.issueToken();

      return isAuthentinicationValid
          ? Response.ok(token)
          : Response.badRequest();
    });

    _app.post('/connect', (Request request) async {
      final payload = await request.readAsString();
      var isValid = _tokenService.validateToken(payload);

      return isValid ? Response.ok(200) : Response.badRequest();
    });

    _app.post('/one-time-connection', (Request request) async {
      final payload = await request.readAsString();

      await Clipboard.setData(
        ClipboardData(
          text: payload,
        ),
      );

      Future.delayed(
        Duration(seconds: 20),
        () async {
          await Clipboard.setData(ClipboardData(text: ""));
        },
      );

      return Response.ok(200);
    });

    _app.post('/set-sync-type', (Request request) async {
      final payload = await request.readAsString();
      var decoded = jsonDecode(payload);
      SyncTypes syncType = SyncTypes.otc;

      switch (decoded["type"]) {
        case "full":
          syncType = SyncTypes.full;
          break;
        case "partial":
          syncType = SyncTypes.partial;
          break;
      }

      _syncService.setSyncType(decoded["id"], syncType);

      return Response.ok(200);
    });

    _app.post('/sync', (Request request) async {
      final payload = await request.readAsString();

      var decoded = jsonDecode(payload);

      List<dynamic> identitiesData = decoded["identities"];
      List<dynamic> secretsData = decoded["secrets"];
      List<dynamic> otpData = decoded["otpSecrets"];

      await _identityManager.importSecrets(
        identitiesData.map((e) => StoredIdentity.fromJson(e)).toList(),
      );

      await _secretManager.importSecrets(
        secretsData.map((e) => StoredSecret.fromJson(e)).toList(),
      );

      await _otpService.importCodes(
        otpData.map((e) => OtpCode.fromJson(e)).toList(),
      );

      return Response.ok(200);
    });

    _server = await io.serve(
      _app,
      '0.0.0.0',
      9787,
      securityContext: dio.SecurityContext()
        ..useCertificateChainBytes(certData.buffer.asUint8List())
        ..usePrivateKeyBytes(
          keyData.buffer.asUint8List(),
        ),
    );
    print("Server is running on 0.0.0.0:9787");
  }

  @override
  Future stopServer() async {
    if (_server == null) return;

    await _server?.close(force: true);
  }
}
