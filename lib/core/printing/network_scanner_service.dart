import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NetworkScannerService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Xin quyền vị trí (bắt buộc trên Android 10+ để đọc WiFi IP)
  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Quét mạng tìm thiết bị mở port 9100 (cổng in RAW/JetDirect — đặc trưng máy in).
  /// Trả về danh sách IP sắp xếp tăng dần.
  Future<List<String>> scanForPrinters({
    int port = 9100,
    int batchSize = 30,
    int timeoutMs = 800,
    void Function(int scanned, int total)? onProgress,
  }) async {
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      throw Exception(
        'Cần quyền truy cập Vị trí để dò tìm máy in qua WiFi.\n'
        'Vui lòng cấp quyền trong Cài đặt điện thoại.',
      );
    }

    final String? wifiIP = await _networkInfo.getWifiIP();
    if (wifiIP == null) {
      throw Exception(
        'Không lấy được địa chỉ IP WiFi.\n'
        'Hãy đảm bảo điện thoại đang kết nối WiFi cùng mạng với máy in.',
      );
    }

    final String subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final List<int> range = List.generate(254, (i) => i + 1);
    final int total = range.length;
    int scanned = 0;
    final List<String> activeIps = [];

    for (int i = 0; i < total; i += batchSize) {
      final int end = (i + batchSize < total) ? i + batchSize : total;
      final batch = range.sublist(i, end);

      final results = await Future.wait(
        batch.map((n) async {
          final host = '$subnet.$n';
          final isOpen = await _checkPort(host, port, timeoutMs: timeoutMs);
          return isOpen ? host : null;
        }),
      );

      for (final ip in results) {
        if (ip != null) activeIps.add(ip);
      }

      scanned += batch.length;
      onProgress?.call(scanned, total);
    }

    // Sắp xếp theo số cuối IP tăng dần
    activeIps.sort((a, b) => int.parse(a.split('.').last)
        .compareTo(int.parse(b.split('.').last)));

    return activeIps;
  }

  Future<bool> _checkPort(String ip, int port, {int timeoutMs = 800}) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
