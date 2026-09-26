import 'dart:io';
import 'package:image/image.dart' as img;
import '../storage/storage_service.dart';
import 'paper_size.dart';
import 'receipt_renderer.dart';

class PrinterService {
  /// In hóa đơn tiếng Việt chuẩn ESC/POS qua mạng LAN
  /// Tự động lấy IP, Port, PaperSize từ StorageService
  /// Tự động render hình ảnh qua ReceiptRenderer với autoFit
  /// Trả về chuỗi kết quả thân thiện với người dùng
  Future<String> printReceipt({
    required StorageService storage,
    required String content,
    double? fontSize,
    bool autoFit = true,
  }) async {
    final ip = storage.ipAddress.trim();
    final port = storage.port;
    final paperSizeStr = storage.paperSize.trim();

    if (ip.isEmpty) {
      return 'Vui lòng cài đặt địa chỉ IP máy in trước trong mục Cài đặt!';
    }

    if (content.trim().isEmpty) {
      return 'Nội dung in không được để trống!';
    }

    try {
      final config = PaperConfig.fromString(paperSizeStr);

      final image = await ReceiptRenderer.renderTextToImage(
        content,
        printWidth: config.printWidth,
        fontSize: fontSize ?? config.defaultFontSize,
        autoFit: autoFit,
      );

      return await printImageBill(
        ip: ip,
        port: port,
        paperSizeStr: config.name,
        image: image,
      );
    } catch (e) {
      return 'Lỗi khi xử lý hình ảnh in: $e';
    }
  }

  /// In nội dung văn bản thô qua mạng LAN (dành cho in test nhanh)
  Future<String> printBill({
    required String ip,
    required int port,
    required String paperSizeStr,
    required String content,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));

      List<int> bytes = [];
      // ESC @ (Khởi tạo máy in)
      bytes.addAll([0x1B, 0x40]);
      // Nội dung text
      bytes.addAll(content.codeUnits);
      // Đẩy giấy 3 dòng và cắt
      bytes.addAll([0x1B, 0x64, 0x03]);
      bytes.addAll([0x1D, 0x56, 0x00]);

      socket.add(bytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 300));
      return 'In thành công!';
    } catch (e) {
      return 'Không thể kết nối đến máy in ($ip:$port): $e';
    } finally {
      socket?.destroy();
    }
  }

  /// In hóa đơn dạng hình ảnh (Raster Image)
  Future<String> printImageBill({
    required String ip,
    required int port,
    required String paperSizeStr,
    required img.Image image,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));

      final bytes = imageToEscPosRaster(image);

      socket.add(bytes);
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 800));
      await socket.close();
      return 'In thành công!';
    } catch (e) {
      return 'Không thể kết nối đến máy in ($ip:$port): $e';
    } finally {
      socket?.destroy();
    }
  }

  /// Chuyển đổi img.Image thành mã lệnh ESC/POS GS v 0
  static List<int> imageToEscPosRaster(img.Image image) {
    final width = image.width;
    final height = image.height;
    final widthBytes = (width + 7) ~/ 8;

    List<int> bytes = [];

    // ESC @: Khởi tạo máy in
    bytes.addAll([0x1B, 0x40]);
    // ESC a 0: Căn lề trái
    bytes.addAll([0x1B, 0x61, 0x00]);
    // FS .: Hủy chế độ chữ tiếng Trung (tránh xung đột ESC/POS trên máy in nhiệt)
    bytes.addAll([0x1C, 0x2E]);

    // GS v 0 m xL xH yL yH
    final xL = widthBytes & 0xFF;
    final xH = (widthBytes >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;

    bytes.addAll([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);

    for (int y = 0; y < height; y++) {
      for (int byteIdx = 0; byteIdx < widthBytes; byteIdx++) {
        int byteVal = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = byteIdx * 8 + bit;
          if (x < width) {
            final pixel = image.getPixel(x, y);
            // Luminance: < 0.6 là màu tối (in nhiệt), >= 0.6 là màu trắng
            if (pixel.luminanceNormalized < 0.6) {
              byteVal |= (1 << (7 - bit));
            }
          }
        }
        bytes.add(byteVal);
      }
    }

    // Đẩy giấy 4 dòng và Cắt giấy (GS V 0)
    bytes.addAll([0x0A, 0x0A, 0x0A, 0x0A]);
    bytes.addAll([0x1D, 0x56, 0x00]);

    return bytes;
  }
}
