import 'dart:convert';
import 'package:domain/models/device.dart';
import 'package:infrastructure/interfaces/ihttp_provider_service.dart';
import 'package:infrastructure/interfaces/ilocal_network_service.dart';
import 'package:domain/models/http_request.dart';

class LocalNetworkService implements ILocalNetworkService {
  late IHttpProviderService _httpProviderService;

  LocalNetworkService(IHttpProviderService httpProviderService) {
    _httpProviderService = httpProviderService;
  }

  @override
  getNetworkData() {
    // TODO: implement getNetworkData
    throw UnimplementedError();
  }

  Future<List<Device?>> scan() async {
    final baseIp = '192.168.1.';
    List<Device> _devices = [];

    final List<Future<Device?>> futures = [];

    for (int i = 1; i <= 255; i++) {
      final target = baseIp + i.toString();

      futures.add(_scanDevice(target, _devices));
    }

    var res = await Future.wait(futures);

    return res.where((element) => element != null).toList();
  }

  Future<Device?> _scanDevice(String target, List<Device> devices) async {
    final ping = await _httpProviderService.getRequest(
      HttpRequest("http://$target:9787/ping", {}, {}),
    );
    print("Sent request to ${"http://$target:9787/ping"}");
    if (ping == null || ping.statusCode != 200) {
      print("Not found");
    } else {
      try {
        var data = jsonDecode(ping.body);
        return Device.fromJson(data);
      } catch (ex) {
        print("Bad Response, data doesn't match the device model");
        return null;
      }
    }
    // Existing processing code
  }
}
