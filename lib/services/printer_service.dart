import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

class PrinterService {
  /// In nội dung hóa đơn qua mạng LAN
  Future<String> printBill({
    required String ip,
    required int port,
    required String paperSizeStr,
    required String content,
  }) async {
    try {
      final PaperSize paper = paperSizeStr == '80' ? PaperSize.mm80 : PaperSize.mm58;
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(paper, profile);

      final PosPrintResult res = await printer.connect(ip, port: port);

      if (res != PosPrintResult.success) {
        return 'Không thể kết nối đến máy in ($ip:$port): ${res.msg}';
      }

      // Xử lý in tiếng Việt: dùng CodeTable CP1258
      printer.text(
        content,
        styles: const PosStyles(
          align: PosAlign.left,
          codeTable: 'CP1258',
        ),
      );
      
      printer.feed(2); // Đẩy giấy lên 2 dòng
      printer.cut();   // Cắt giấy

      printer.disconnect();
      return 'In thành công!';
    } catch (e) {
      return 'Lỗi khi in: $e';
    }
  }

  /// In hóa đơn dạng hình ảnh (Raster Image) để hỗ trợ Tiếng Việt có dấu 100%
  Future<String> printImageBill({
    required String ip,
    required int port,
    required String paperSizeStr,
    required img.Image image,
  }) async {
    try {
      final PaperSize paper = paperSizeStr == '80' ? PaperSize.mm80 : PaperSize.mm58;
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(paper, profile);

      final PosPrintResult res = await printer.connect(ip, port: port);

      if (res != PosPrintResult.success) {
        return 'Không thể kết nối đến máy in ($ip:$port): ${res.msg}';
      }

      printer.imageRaster(image);
      
      printer.feed(2); // Đẩy giấy lên 2 dòng
      printer.cut();   // Cắt giấy

      printer.disconnect();
      return 'In thành công!';
    } catch (e) {
      return 'Lỗi khi in ảnh: $e';
    }
  }
}
