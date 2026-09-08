import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:toastification/toastification.dart';
import '../services/storage_service.dart';
import '../services/printer_service.dart';
import '../utils/vn_utils.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({Key? key, required this.storageService}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _contentController = TextEditingController();
  final PrinterService _printerService = PrinterService();
  bool _isPrinting = false;

  void _printBill() async {
    final ip = widget.storageService.ipAddress;
    final port = widget.storageService.port;
    final paperSize = widget.storageService.paperSize;
    final content = _contentController.text;

    if (ip.isEmpty) {
      _showSnackBar('Vui lòng cài đặt địa chỉ IP máy in trước!', isError: true);
      return;
    }

    if (content.isEmpty) {
      _showSnackBar('Vui lòng nhập nội dung hóa đơn!', isError: true);
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final double printWidth = paperSize == '80' ? 576 : 384;
      
      Widget receiptWidget = Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: printWidth,
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: Text(
            content,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24, 
              fontFamily: 'monospace',
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
      setState(() {
        _isPrinting = false;
      });

      _showSnackBar(
        resultMsg,
        isError: resultMsg.contains('Lỗi') || resultMsg.contains('Không thể'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPrinting = false;
      });
      _showSnackBar('Lỗi xử lý hình ảnh: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    toastification.show(
      context: context,
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      showProgressBar: false,
      applyBlurEffect: true,
    );
  }

  String _formatPreviewText(String text, int maxWidth) {
    final lines = text.split('\n');
    final result = <String>[];
    for (var line in lines) {
      if (line.isEmpty) {
        result.add('');
        continue;
      }
      while (line.length > maxWidth) {
        result.add(line.substring(0, maxWidth));
        line = line.substring(maxWidth);
      }
      result.add(line);
    }
    return result.join('\n');
  }

  Widget _buildEditorTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShadInput(
              controller: _contentController,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              placeholder: const Text('Nhập nội dung hóa đơn vào đây...'),
            ),
          ),
          const SizedBox(height: 20),
          _buildPrintButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    final paperSizeStr = widget.storageService.paperSize;
    final is80mm = paperSizeStr == '80';
    final maxWidth = is80mm ? 48 : 32;
    
    // Format text
    final previewText = _formatPreviewText(_contentController.text, maxWidth);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '--- MÔ PHỎNG GIẤY ${is80mm ? '80MM' : '58MM'} ---',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA1A1AA),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Text hiển thị hóa đơn
                      Text(
                        previewText.isEmpty ? 'Chưa có nội dung...' : previewText,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          color: Colors.black,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '----------------------------------',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA1A1AA),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildPrintButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPrintButton() {
    return SizedBox(
      width: double.infinity,
      child: ShadButton(
        onPressed: _isPrinting ? null : _printBill,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isPrinting
              ? const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(LucideIcons.printer, size: 16),
                ),
            const Text('In Hóa Đơn'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'In Tự Do',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          actions: [
            ShadButton.ghost(
              child: const Icon(LucideIcons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SettingsScreen(storageService: widget.storageService),
                  ),
                ).then((_) {
                  setState(() {});
                });
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chỉnh sửa'),
              Tab(text: 'Xem trước'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildEditorTab(),
              _buildPreviewTab(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
