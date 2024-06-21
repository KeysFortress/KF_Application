import 'package:domain/models/stored_secret.dart';
import 'package:infrastructure/interfaces/ICloudSecrets_service.dart';
import 'package:infrastructure/interfaces/icloud_service.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:domain/models/cloud_connection_code.dart';
import 'package:domain/models/http_request.dart';

class CloudSecretsService implements ICloudSecretsService {
  late IHttpProviderService _providerService;
  late ICloudService _cloudService;

  CloudSecretsService(
      IHttpProviderService providerService, ICloudService cloudService) {
    _providerService = providerService;
    _cloudService = cloudService;
  }

  @override
  Future<List<StoredSecret>> get(CloudConnectionCode token) async {
    String bearer = await _cloudService.getBearer(token);
    var request = await _providerService.getRequest(
      isAuthenticated: false,
      HttpRequest(
        token.url,
        {"Authorization": "Bearer $bearer"},
        {},
      ),
    );

    if (request == null || request.statusCode != 200) return [];

    return [];
  }

  @override
  Future<bool> delete(StoredSecret secret, CloudConnectionCode token) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<bool> update(StoredSecret secret, CloudConnectionCode token) {
    // TODO: implement update
    throw UnimplementedError();
  }
}
