import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';

class NetworkScannerService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Quét mạng nội bộ theo từng batch nhỏ để tránh nghẽn mạng.
  /// [onProgress] callback trả về (scanned, total) để cập nhật UI tiến trình.
  Future<List<String>> scanForPrinters({
    int port = 9100,
    int batchSize = 30,
    int timeoutMs = 800,
    void Function(int scanned, int total)? onProgress,
  }) async {
    final List<String> activeIps = [];
    final String? wifiIP = await _networkInfo.getWifiIP();

    if (wifiIP == null) {
      return activeIps;
    }

    final String subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final List<int> range = List.generate(254, (i) => i + 1);
    final int total = range.length;
    int scanned = 0;

    // Quét theo batch để tránh mở quá nhiều socket cùng lúc
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

    // Sắp xếp theo thứ tự IP tăng dần
    activeIps.sort((a, b) {
      final aParts = a.split('.').last;
      final bParts = b.split('.').last;
      return int.parse(aParts).compareTo(int.parse(bParts));
    });

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
