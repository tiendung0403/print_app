import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';

class NetworkScannerService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Quét mạng nội bộ để tìm các địa chỉ IP đang mở port (mặc định 9100 cho máy in)
  Future<List<String>> scanForPrinters({int port = 9100}) async {
    final List<String> activeIps = [];
    final String? wifiIP = await _networkInfo.getWifiIP();
    
    if (wifiIP == null) {
      return activeIps; // Không có kết nối wifi
    }

    final String subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final List<Future<void>> futures = [];

    // Quét từ 1 đến 254
    for (int i = 1; i < 255; i++) {
      final String host = '$subnet.$i';
      futures.add(_checkPort(host, port).then((isOpen) {
        if (isOpen) {
          activeIps.add(host);
        }
      }));
    }

    // Chờ quét xong tất cả
    await Future.wait(futures);
    return activeIps;
  }

  Future<bool> _checkPort(String ip, int port) async {
    try {
      // Đặt timeout ngắn (ví dụ 500ms) để quét nhanh
      final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 500));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }
}
