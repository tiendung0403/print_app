import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ReceiptRenderer {
  /// Render chuỗi văn bản Tiếng Việt thành hình ảnh bitmap trắng đen (Raster Image)
  /// Sử dụng TextPainter + Canvas của Flutter: cực nhanh (< 10ms), chuẩn font 100% Tiếng Việt có dấu,
  /// Hỗ trợ autoFitWidth để chữ tự động co giãn vừa khít khổ giấy (58mm hoặc 80mm).
  static Future<img.Image> renderTextToImage(
    String content, {
    required int printWidth,
    double? fontSize,
    bool autoFit = false,
  }) async {
    // Chiều rộng hiệu dụng để in (trừ 16px lề: 8px mỗi bên)
    final double targetContentWidth = math.max(100.0, (printWidth - 16).toDouble());

    double effectiveFontSize = fontSize ?? 20.0;

    if (autoFit) {
      // Tìm dòng dài nhất để tính cỡ chữ vừa khít khổ giấy
      final lines = content.split('\n');
      String longestLine = '';
      for (final line in lines) {
        final trimmed = line.trimRight();
        if (trimmed.length > longestLine.length) {
          longestLine = trimmed;
        }
      }

      if (longestLine.isNotEmpty) {
        final measurePainter = TextPainter(
          text: TextSpan(
            text: longestLine,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.0,
              letterSpacing: 0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        if (measurePainter.width > 0) {
          final fitSize = (targetContentWidth / measurePainter.width) * 10.0;
          effectiveFontSize = fitSize.clamp(14.0, 28.0);
        }
      }
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          color: Colors.black,
          fontSize: effectiveFontSize,
          fontFamily: 'monospace',
          height: 1.25,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: targetContentWidth);

    final contentHeight = textPainter.height;
    final totalHeight = math.max(1, (contentHeight + 24).ceil());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, printWidth.toDouble(), totalHeight.toDouble()),
    );

    // Vẽ nền trắng
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, printWidth.toDouble(), totalHeight.toDouble()),
      bgPaint,
    );

    // Vẽ chữ màu đen (căn lề trên 12px, lề trái 8px)
    textPainter.paint(canvas, const Offset(8, 12));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(printWidth, totalHeight);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw Exception('Không thể xuất dữ liệu hình ảnh hóa đơn');
    }

    return img.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: byteData.buffer,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    );
  }
}
