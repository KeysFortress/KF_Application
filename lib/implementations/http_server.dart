import 'dart:io' as dio;

import 'package:infrastructure/interfaces/ihttp_server.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

class HttpServer implements IHttpServer {
  dio.HttpServer? _server;

  @override
  restartServer() async {
    await _server?.close(force: true);
    await startServer();
  }

  @override
  startServer() async {
    var app = Router();

    app.get('/request-pair/<key>', (shelf.Request request, String key) {
      return shelf.Response.ok('hello-world $key');
    });

    app.post('/pair', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    app.post('/connect', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    app.post('/one-time-connection', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    app.post('/full-sync', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    app.post('/partial-sync', (shelf.Request request) async {
      final payload = await request.readAsString();

      return shelf.Response.ok(200);
    });

    _server = await io.serve(app, 'localhost', 9787);
  }

  @override
  stopServer() async {
    if (_server == null) return;

    await _server?.close(force: true);
  }
}
