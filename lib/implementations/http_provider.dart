// ignore_for_file: avoid_shadowing_type_parameters

import 'dart:convert';
import 'dart:io';

import 'dart:math';

import 'package:domain/models/http_request.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

import 'package:infrastructure/interfaces/ihttp_provider_service.dart';

class HttpProvider<T> implements IHttpProviderService {
  String? sessionToken;
  List<int> cIds = [];
  late IOClient _ioClient;
  HttpProvider() {
    var ioClient = HttpClient()..badCertificateCallback = validateCertificate;
    _ioClient = IOClient(ioClient);
  }

  bool validateCertificate(X509Certificate cert, String host, int port) {
    print(host);
    print(cert.issuer);
    return true;
  }

  @override
  Future<Response?> getRequest(
    HttpRequest request, {
    bool isAuthenticated = false,
    String tokenType = "auth-token",
    String header = "authorization",
    String prefix = "Bearer ",
    int timeout = 0,
  }) async {
    try {
      request = await checkAuthStatus(
        isAuthenticated,
        request,
        tokenType,
        header,
        prefix,
      );

      return timeout > 0
          ? await _ioClient
              .get(Uri.parse(request.url), headers: request.headers)
              .timeout(
                Duration(seconds: timeout),
              )
          : await _ioClient.get(Uri.parse(request.url),
              headers: request.headers);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Response?> postRequest(
    HttpRequest request, {
    bool isAuthenticated = false,
    String tokenType = "auth-token",
    String header = "authorization",
    String prefix = "Bearer ",
    bool dontCast = false,
    int timeout = 0,
  }) async {
    try {
      return timeout > 0
          ? await _ioClient
              .post(
                Uri.parse(request.url),
                headers: {
                  ...request.headers,
                  'Content-Type': 'application/json',
                },
                body: request.params,
              )
              .timeout(
                Duration(
                  seconds: timeout,
                ),
              )
          : await _ioClient.post(
              Uri.parse(request.url),
              headers: {
                ...request.headers,
                'Content-Type': 'application/json',
              },
              body: request.params,
            );
    } catch (ex) {
      return null;
    }
  }

  @override
  Future<Response?> putReqest(
    HttpRequest request, {
    bool isAuthenticated = false,
    String tokenType = "auth-token",
    String header = "authorization",
    String prefix = "Bearer ",
    int timeout = 0,
  }) async {
    try {
      request = await checkAuthStatus(
        isAuthenticated,
        request,
        tokenType,
        header,
        prefix,
      );

      return timeout > 0
          ? await _ioClient
              .put(
                Uri.parse(request.url),
                headers: request.headers,
                body: jsonEncode(request.params),
              )
              .timeout(
                Duration(seconds: timeout),
              )
          : await _ioClient.put(
              Uri.parse(request.url),
              headers: request.headers,
              body: jsonEncode(request.params),
            );
    } catch (e) {
      return null;
    }
  }

  Future<HttpRequest> checkAuthStatus(
    bool isAuthenticated,
    HttpRequest request,
    String tokenType,
    String header,
    String prefix,
  ) async {
    return request;
  }

  String createCryptoRandomString([int length = 128]) {
    var random = Random.secure();

    var values = List<int>.generate(length, (i) => random.nextInt(256));

    return base64ToHex(base64Encode(values));
  }

  String base64ToHex(String source) =>
      base64Decode(LineSplitter.split(source).join())
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join();

  getPublicKey() async {
    return await rootBundle.loadString('packages/domain/assets/user_token.pub');
  }

  validateAccessToken(String token) async {
    // var certificate = await getPublicKey();
    // JWT? verify = JWT.tryVerify(token, RSAPublicKey(certificate));
    // if (verify != null) {
    //   var payload = verify.payload as Map<String, dynamic>;
    //   var existing = payload['access'] as List<dynamic>;
    //   existing.map((e) => cIds.add(e)).toList();
    // }
  }

  @override
  void setToken(String token, value) {}
}
