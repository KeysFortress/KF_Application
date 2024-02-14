import 'dart:convert';
import 'dart:io' as dio;
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/gestures.dart';
import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

class HttpServer implements IHttpServer {
  late ILocalNetworkService _localNetworkService;
  late ISignatureService _signatureService;
  dio.HttpServer? _server;
  late Router _app;

  HttpServer(ILocalNetworkService localNetworkService,
      ISignatureService signatureService) {
    _localNetworkService = localNetworkService;
    _signatureService = signatureService;
  }

  @override
  Future restartServer() async {
    await _server?.close(force: true);
    await startServer();
  }

  @override
  Future startServer() async {
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

    _app.get('/request-pair/<key>', (Request request, String key) async {
      var keys = await _localNetworkService.getCredentails();
      var publicKey = await _signatureService.importPublic(key);
      var generatedSignature =
          await _signatureService.signMessage(publicKey, "asd");

      return Response.ok(generatedSignature);
    });

    _app.get('/login/<key>', (Request request, String key) {
      return Response.ok('hello-world $key');
    });

    _app.post('/pair', (Request request) async {
      final payload = await request.readAsString();

      return Response.ok(200);
    });

    _app.post('/connect', (Request request) async {
      final payload = await request.readAsString();

      return Response.ok(200);
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
      securityContext: SecurityContext()
        ..useCertificateChain('path/to/cert.pem')
        ..usePrivateKey('path/to/key.pem'),
    );
    print("Server is running on 127.0.0.1:9787");
  }

  @override
  Future stopServer() async {
    if (_server == null) return;

    await _server?.close(force: true);
  }
}
