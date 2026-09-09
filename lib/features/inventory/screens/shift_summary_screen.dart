import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import '../models/shift_record.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/printing/printer_service.dart';
import '../../../core/printing/paper_size.dart';
import '../../../core/utils/vn_utils.dart';
import 'package:toastification/toastification.dart';

class ShiftSummaryScreen extends StatefulWidget {
  final ShiftRecord shift;
  final StorageService storageService;

  const ShiftSummaryScreen({Key? key, required this.shift, required this.storageService}) : super(key: key);

  @override
  _ShiftSummaryScreenState createState() => _ShiftSummaryScreenState();
}

class _ShiftSummaryScreenState extends State<ShiftSummaryScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final PrinterService _printerService = PrinterService();
  String _summaryText = '';
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  Future<void> _generateSummary() async {
    setState(() => _isLoading = true);
    
    final items = await _db.getItems();
    final entries = await _db.getEntriesForShift(widget.shift.id!);
    final enableRounding = widget.storageService.enableRounding;
    
    final is80mm = widget.storageService.paperSize == '80';
    final lineWidth = is80mm ? 48 : 32;
    final separator = '-' * lineWidth;
    
    final col1Len = is80mm ? 20 : 12;
    final col2Len = is80mm ? 13 : 9;
    final col3Len = is80mm ? 15 : 11;

    StringBuffer sb = StringBuffer();
    sb.writeln(separator);
    final printTitle = widget.shift.printTitle.trim().isNotEmpty ? widget.shift.printTitle : widget.shift.name;
    sb.writeln(printTitle.padRight(lineWidth));
    sb.writeln(separator);
    
    String header1 = 'TÊN MÓN'.padRight(col1Len);
    String header2 = 'S.LƯỢNG'.padLeft(col2Len);
    String header3 = 'PHẦN'.padLeft(col3Len);
    sb.writeln('$header1$header2$header3');
    
    sb.writeln(separator);

    for (var item in items) {
      final itemLogs = entries.where((e) => e.itemId == item.id).toList();
      if (itemLogs.isEmpty) continue;

      Map<String, double> unitRates = { item.baseUnit: item.conversionRate };
      if (item.customUnitsJson != '[]') {
        try {
          List<dynamic> parsed = jsonDecode(item.customUnitsJson);
          for (var u in parsed) {
            unitRates[u['name']] = (u['rate'] as num).toDouble();
          }
        } catch (e) {}
      }

      double finalTotalPortions = 0.0;
      double totalBaseUnits = 0.0;

      for (var log in itemLogs) {
        if (log.enteredUnit == 'P') {
          finalTotalPortions += log.enteredValue;
          totalBaseUnits += (log.enteredValue * item.conversionRate);
        } else {
          double rate = unitRates[log.enteredUnit] ?? item.conversionRate;
          if (rate > 0) {
            finalTotalPortions += (log.enteredValue / rate);
            totalBaseUnits += (log.enteredValue / rate) * item.conversionRate;
          }
        }
      }

      String qtyStr = '${totalBaseUnits.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}${item.baseUnit}';

      String resultStr = '';
      if (enableRounding) {
        int wholePortions = finalTotalPortions.floor();
        double remainderBaseUnits = (finalTotalPortions - wholePortions) * item.conversionRate;
        
        if (remainderBaseUnits > 0.01) {
          // Has remainder
          String remStr = remainderBaseUnits.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
          resultStr = '${wholePortions}P ${remStr}${item.baseUnit}';
        } else {
          resultStr = '${wholePortions}P';
        }
      } else {
        String pStr = finalTotalPortions.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
        resultStr = '${pStr}P';
      }

      String safeName = item.name;
      if (safeName.length > col1Len) safeName = safeName.substring(0, col1Len);
      
      String col1 = safeName.padRight(col1Len);
      String col2 = qtyStr.padLeft(col2Len);
      String col3 = resultStr.padLeft(col3Len);
      
      sb.writeln('$col1$col2$col3');
    }

    sb.writeln(separator);
    
    setState(() {
      _summaryText = sb.toString();
      _isLoading = false;
    });
  }

  void _printPreview() async {
    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Bản xem trước'),
          closeIcon: const SizedBox.shrink(),
          description: Container(
            width: 340,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SingleChildScrollView(
              child: Text(
                _summaryText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black),
              ),
            ),
          ),
          actions: [
            ShadButton.outline(
              child: const Text('Đóng'),
              onPressed: () => Navigator.pop(context),
            ),
            ShadButton(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(LucideIcons.printer, size: 16),
                  ),
                  Text('In Ngay'),
                ],
              ),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _executePrint(_summaryText);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _executePrint(String content) async {
    final ip = widget.storageService.ipAddress;
    final port = widget.storageService.port;
    final paperSize = widget.storageService.paperSize;

    if (ip.isEmpty) {
      _showToast('Vui lòng cài đặt địa chỉ IP máy in trước!', isError: true);
      return;
    }

    setState(() => _isPrinting = true);
    
    try {
      final pSize = parsePaperSize(paperSize);
      final double printWidth = getPrintWidth(pSize).toDouble();
      
      final fontSize = getReceiptFontSize(pSize);

      Widget receiptWidget = Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: printWidth,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(
            content,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize,
              fontFamily: 'monospace',
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
        ),
      );

      final screenshotController = ScreenshotController();
      final Uint8List capturedImage = await screenshotController.captureFromWidget(
        receiptWidget,
        delay: const Duration(milliseconds: 100),
      );
      
      final decodedImage = img.decodeImage(capturedImage);
      if (decodedImage == null) {
        throw Exception('Không thể giải mã hình ảnh');
      }

      final resultMsg = await _printerService.printImageBill(
        ip: ip,
        port: port,
        paperSizeStr: paperSize,
        image: decodedImage,
      );

      if (!mounted) return;
      setState(() => _isPrinting = false);

      _showToast(
        resultMsg,
        isError: resultMsg.contains('Lỗi') || resultMsg.contains('Không thể'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      _showToast('Lỗi xử lý hình ảnh: $e', isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    toastification.show(
      context: context,
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng kết Ca', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Text(
                        _summaryText,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton(
                    onPressed: _isPrinting ? null : _printPreview,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isPrinting 
                          ? const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Icon(LucideIcons.printer, size: 16),
                            ),
                        Text(_isPrinting ? 'Đang kết nối máy in...' : 'Xem Trước & In Báo Cáo'),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
    );
  }
}
