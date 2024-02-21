import 'dart:convert';
import 'dart:io' as dio;

import 'package:flutter/services.dart';
import 'package:infrastructure/interfaces/ichallanage_service.dart';
import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:infrastructure/interfaces/isignature_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

class HttpServer implements IHttpServer {
  late ILocalNetworkService _localNetworkService;
  late ISignatureService _signatureService;
  late IChallangeService _challangeService;

  dio.HttpServer? _server;
  late Router _app;

  HttpServer(ILocalNetworkService localNetworkService,
      ISignatureService signatureService, IChallangeService challangeService) {
    _localNetworkService = localNetworkService;
    _signatureService = signatureService;
    _challangeService = challangeService;
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

    _app.get('/request-pair/<key>', (Request request, String key) async {
      var challange = _challangeService.issue(key);
      return Response.ok(challange);
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
