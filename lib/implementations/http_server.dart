import 'dart:convert';
import 'dart:io' as dio;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:infrastructure/interfaces/ichallanage_service.dart';
import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:infrastructure/interfaces/itoken_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:domain/converters/binary_converter.dart';

class HttpServer implements IHttpServer {
  late ILocalNetworkService _localNetworkService;
  late ISignatureService _signatureService;
  late IChallangeService _challangeService;
  late ITokenService _tokenService;

  dio.HttpServer? _server;
  late Router _app;

  HttpServer(
      ILocalNetworkService localNetworkService,
      ISignatureService signatureService,
      IChallangeService challangeService,
      ITokenService tokenService) {
    _localNetworkService = localNetworkService;
    _signatureService = signatureService;
    _challangeService = challangeService;
    _tokenService = tokenService;
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

      return Response.ok(200);
    });

    _app.post('/full-sync', (Request request) async {
      final payload = await request.readAsString();

      return Response.ok(200);
    });

    _app.post('/partial-sync', (Request request) async {
      final payload = await request.readAsString();

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
