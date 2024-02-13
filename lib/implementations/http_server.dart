import 'dart:convert';
import 'dart:io' as dio;

import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

class HttpServer implements IHttpServer {
  late ILocalNetworkService _localNetworkService;
  dio.HttpServer? _server;
  late Router _app;

  HttpServer(ILocalNetworkService localNetworkService) {
    _localNetworkService = localNetworkService;
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

    _app.get('/request-pair/<key>', (Request request, String key) {
      print("Incoming request");
      return Response.ok('hello-world $key');
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

    _server = await io.serve(_app, '0.0.0.0', 9787);
    print("Server is running on 127.0.0.1:9787");
  }

  @override
  Future stopServer() async {
    if (_server == null) return;

    await _server?.close(force: true);
  }
}
