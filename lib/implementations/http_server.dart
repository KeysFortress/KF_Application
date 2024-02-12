import 'dart:io' as dio;

import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

class HttpServer implements IHttpServer {
  dio.HttpServer? _server;
  late Router _app;
  @override
  Future restartServer() async {
    await _server?.close(force: true);
    await startServer();
  }

  @override
  Future startServer() async {
    _app = Router();

    _app.get("/ping", (shelf.Request request) {
      return shelf.Response.ok('hello-world');
    });

    _app.get('/request-pair/<key>', (shelf.Request request, String key) {
      print("Incoming request");
      return shelf.Response.ok('hello-world $key');
    });

    _app.get('/login/<key>', (shelf.Request request, String key) {
      return shelf.Response.ok('hello-world $key');
    });

    _app.post('/pair', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    _app.post('/connect', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    _app.post('/one-time-connection', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    _app.post('/full-sync', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    _app.post('/partial-sync', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    _server = await io.serve(_app, 'localhost', 9787);
    print("Server is running on 127.0.0.1:9787");
  }

  @override
  Future stopServer() async {
    if (_server == null) return;

    await _server?.close(force: true);
  }
}
