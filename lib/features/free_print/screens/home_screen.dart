import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:toastification/toastification.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/printing/printer_service.dart';
import '../../../core/printing/paper_size.dart';
import '../../settings/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({super.key, required this.storageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _contentController = TextEditingController();
  final PrinterService _printerService = PrinterService();
  bool _isPrinting = false;

  void _printBill() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('Vui lòng nhập nội dung hóa đơn!', isError: true);
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    final paperConfig = PaperConfig.fromString(widget.storageService.paperSize);
    // Cỡ chữ Lớn: 80mm là 26.0px, 58mm là 22.0px (to rõ, sắc nét)
    final double largeFontSize = paperConfig.size == PaperSize.mm80 ? 26.0 : 22.0;

    final resultMsg = await _printerService.printReceipt(
      storage: widget.storageService,
      content: content,
      fontSize: largeFontSize,
      autoFit: false,
    );

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
    });

    _showSnackBar(
      resultMsg,
      isError: resultMsg.contains('Lỗi') || resultMsg.contains('Không thể') || resultMsg.contains('Vui lòng'),
    );
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
          const SizedBox(height: 16),
          _buildPrintButton(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    final paperConfig = PaperConfig.fromString(widget.storageService.paperSize);
    final is80mm = paperConfig.size == PaperSize.mm80;
    // Cỡ chữ Lớn: 80mm hiển thị ~35 ký tự/dòng, 58mm hiển thị ~27 ký tự/dòng
    final maxWidth = is80mm ? 35 : 27;
    
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
