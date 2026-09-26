import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ProcessedImageResult {
  final img.Image processedImage;
  final Uint8List previewBytes;
  final int originalWidth;
  final int originalHeight;
  final int printWidth;
  final int printHeight;

  ProcessedImageResult({
    required this.processedImage,
    required this.previewBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.printWidth,
    required this.printHeight,
  });
}

class ImageProcessor {
  /// Xử lý ảnh cho máy in nhiệt (ESC/POS)
  /// - targetWidth: Chiều rộng in (80mm: 576 dots, 58mm: 384 dots)
  /// - useDithering: true dùng thuật toán Floyd-Steinberg (tối ưu cho ảnh chụp), false dùng phân ngưỡng độ sáng (tối ưu cho logo, chữ)
  /// - threshold: Ngưỡng phân chia sáng tối (0.1 - 0.9, mặc định 0.5)
  static Future<ProcessedImageResult> processImage(
    Uint8List rawBytes, {
    required int targetWidth,
    bool useDithering = true,
    double threshold = 0.5,
  }) async {
    // 1. Decode ảnh từ dữ liệu byte
    final originalImage = img.decodeImage(rawBytes);
    if (originalImage == null) {
      throw Exception('Không thể giải mã định dạng hình ảnh này.');
    }

    final origW = originalImage.width;
    final origH = originalImage.height;

    // 2. Chuẩn hóa targetWidth chia hết cho 8 (chuẩn byte của ESC/POS)
    final effectiveWidth = (targetWidth ~/ 8) * 8;
    // Tính chiều cao theo tỷ lệ gốc
    final effectiveHeight = ((origH * effectiveWidth) / origW).round();

    // 3. Resize ảnh về đúng kích thước khổ giấy in nhiệt
    final resized = img.copyResize(
      originalImage,
      width: effectiveWidth,
      height: effectiveHeight,
      interpolation: img.Interpolation.linear,
    );

    // 4. Lấy ma trận độ sáng (luminance)
    final width = resized.width;
    final height = resized.height;
    final lum = List<Float64List>.generate(height, (_) => Float64List(width));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        lum[y][x] = pixel.luminanceNormalized * 255.0;
      }
    }

    // 5. Áp dụng thuật toán Binarization / Floyd-Steinberg Dithering
    final resultImage = img.Image(width: width, height: height, numChannels: 4);
    final threshVal = threshold.clamp(0.05, 0.95) * 255.0;

    if (useDithering) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final oldVal = lum[y][x];
          final newVal = oldVal < threshVal ? 0.0 : 255.0;
          final error = oldVal - newVal;

          final c = newVal.round();
          resultImage.setPixelRgba(x, y, c, c, c, 255);

          // Phân phối sai số cho các điểm ảnh lân cận (Floyd-Steinberg kernel)
          if (x + 1 < width) {
            lum[y][x + 1] += error * (7.0 / 16.0);
          }
          if (y + 1 < height) {
            if (x > 0) {
              lum[y + 1][x - 1] += error * (3.0 / 16.0);
            }
            lum[y + 1][x] += error * (5.0 / 16.0);
            if (x + 1 < width) {
              lum[y + 1][x + 1] += error * (1.0 / 16.0);
            }
          }
        }
      }
    } else {
      // Phân ngưỡng tĩnh đơn giản
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final c = lum[y][x] < threshVal ? 0 : 255;
          resultImage.setPixelRgba(x, y, c, c, c, 255);
        }
      }
    }

    // 6. Encode ra PNG bytes để hiển thị preview chuẩn xác trên màn hình
    final previewPng = Uint8List.fromList(img.encodePng(resultImage));

    return ProcessedImageResult(
      processedImage: resultImage,
      previewBytes: previewPng,
      originalWidth: origW,
      originalHeight: origH,
      printWidth: width,
      printHeight: height,
    );
  }
}
