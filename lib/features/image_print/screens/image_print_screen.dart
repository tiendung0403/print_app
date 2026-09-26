import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:toastification/toastification.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/printing/printer_service.dart';
import '../../../core/printing/paper_size.dart';
import '../../../core/printing/image_processor.dart';
import '../../settings/screens/settings_screen.dart';

class ImagePrintScreen extends StatefulWidget {
  final StorageService storageService;

  const ImagePrintScreen({super.key, required this.storageService});

  @override
  State<ImagePrintScreen> createState() => _ImagePrintScreenState();
}

class _ImagePrintScreenState extends State<ImagePrintScreen> with SingleTickerProviderStateMixin {
  final PrinterService _printerService = PrinterService();
  File? _selectedFile;
  ProcessedImageResult? _processedResult;
  bool _isProcessing = false;
  bool _isPrinting = false;
  bool _useDithering = true;
  double _threshold = 0.5;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (result != null && result.path != null) {
        final file = File(result.path!);
        setState(() {
          _selectedFile = file;
        });
        await _processCurrentImage();
      }
    } catch (e) {
      _showToast('Không thể chọn ảnh: $e', isError: true);
    }
  }

  Future<void> _processCurrentImage() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final paperConfig = PaperConfig.fromString(widget.storageService.paperSize);

      final result = await ImageProcessor.processImage(
        bytes,
        targetWidth: paperConfig.printWidth,
        useDithering: _useDithering,
        threshold: _threshold,
      );

      if (!mounted) return;
      setState(() {
        _processedResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showToast('Lỗi khi xử lý ảnh: $e', isError: true);
    }
  }

  Future<void> _printImage() async {
    if (_processedResult == null) {
      _showToast('Vui lòng chọn ảnh trước khi in!', isError: true);
      return;
    }

    final ip = widget.storageService.ipAddress.trim();
    if (ip.isEmpty) {
      _showToast('Vui lòng cài đặt địa chỉ IP máy in trong mục Cài Đặt!', isError: true);
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    final paperConfig = PaperConfig.fromString(widget.storageService.paperSize);
    final msg = await _printerService.printImageBill(
      ip: ip,
      port: widget.storageService.port,
      paperSizeStr: paperConfig.name,
      image: _processedResult!.processedImage,
    );

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
    });

    final isError = msg.contains('Không thể') || msg.contains('Lỗi') || msg.contains('Vui lòng');
    _showToast(msg, isError: isError);
  }

  void _clearImage() {
    setState(() {
      _selectedFile = null;
      _processedResult = null;
    });
  }

  void _showToast(String message, {bool isError = false}) {
    toastification.show(
      context: context,
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
      showProgressBar: false,
    );
  }

  Widget _buildEmptyState() {
    final paperConfig = PaperConfig.fromString(widget.storageService.paperSize);
    final is80mm = paperConfig.size == PaperSize.mm80;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.image,
                size: 64,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có ảnh nào được chọn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Chỉ chọn 1 ảnh để in - Tự động co giãn vừa vặn khổ giấy ${is80mm ? '80mm (576px)' : '58mm (384px)'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: ShadButton(
                onPressed: _pickImage,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.imagePlus, size: 18),
                    SizedBox(width: 8),
                    Text('Chọn 1 Hình Ảnh'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageEditor() {
    final paperConfig = PaperConfig.fromString(widget.storageService.paperSize);
    final is80mm = paperConfig.size == PaperSize.mm80;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row chứa thông tin và nút đổi/xóa ảnh
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.printer, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Khổ in: ${is80mm ? '80mm (576px)' : '58mm (384px)'}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                onPressed: _pickImage,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.imagePlus, size: 16),
                    SizedBox(width: 4),
                    Text('Đổi ảnh'),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ShadButton.destructive(
                onPressed: _clearImage,
                child: const Icon(LucideIcons.trash2, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs xem trước: Bản in nhiệt vs Ảnh gốc
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Mô phỏng bản in nhiệt'),
              Tab(text: 'Ảnh gốc'),
            ],
          ),
          const SizedBox(height: 12),

          // Khung hiển thị ảnh preview
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Bản in nhiệt (giả lập giấy in nhiệt trắng xám)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: _isProcessing
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Đang tối ưu hóa ảnh cho máy in...'),
                            ],
                          ),
                        )
                      : (_processedResult != null
                          ? InteractiveViewer(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.memory(
                                    _processedResult!.previewBytes,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none, // Hiển thị chuẩn dot ma trận
                                  ),
                                ),
                              ),
                            )
                          : const Center(child: Text('Chưa xử lý được ảnh'))),
                ),

                // Tab 2: Ảnh gốc
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InteractiveViewer(
                      child: Image.file(
                        _selectedFile!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card tùy chỉnh thông số in ảnh
          ShadCard(
            title: const Text('Tùy Chỉnh Bản In', style: TextStyle(fontWeight: FontWeight.bold)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text('Chế độ xử lý ảnh:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ShadButton(
                        onPressed: () {
                          if (!_useDithering) {
                            setState(() => _useDithering = true);
                            _processCurrentImage();
                          }
                        },
                        gradient: _useDithering
                            ? null
                            : const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
                        backgroundColor: _useDithering ? null : Colors.grey.shade200,
                        foregroundColor: _useDithering ? null : Colors.black87,
                        child: const Text('Đổ bóng (Dithering)\n(Cho ảnh chụp)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShadButton(
                        onPressed: () {
                          if (_useDithering) {
                            setState(() => _useDithering = false);
                            _processCurrentImage();
                          }
                        },
                        gradient: !_useDithering
                            ? null
                            : const LinearGradient(colors: [Colors.transparent, Colors.transparent]),
                        backgroundColor: !_useDithering ? null : Colors.grey.shade200,
                        foregroundColor: !_useDithering ? null : Colors.black87,
                        child: const Text('Đen trắng thuần\n(Cho logo / chữ)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Thanh trượt điều chỉnh sáng / tối
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Độ đậm nét (Ngưỡng sáng):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${(_threshold * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Slider(
                  value: _threshold,
                  min: 0.15,
                  max: 0.85,
                  divisions: 14,
                  onChanged: (val) {
                    setState(() => _threshold = val);
                  },
                  onChangeEnd: (_) {
                    _processCurrentImage();
                  },
                ),
                const SizedBox(height: 8),

                // Thông số kích thước
                if (_processedResult != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Kích thước in nhiệt: ${_processedResult!.printWidth} x ${_processedResult!.printHeight} px',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '• Kích thước ảnh gốc: ${_processedResult!.originalWidth} x ${_processedResult!.originalHeight} px',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Nút In Ảnh
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              onPressed: (_isPrinting || _isProcessing) ? null : _printImage,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPrinting) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text('Đang Gửi Dữ Liệu Tới Máy In...'),
                  ] else ...[
                    const Icon(LucideIcons.printer, size: 18),
                    const SizedBox(width: 8),
                    Text('In Ảnh Ngay (Khổ ${is80mm ? '80mm' : '58mm'})'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'In Hình Ảnh',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          ShadButton.ghost(
            child: const Icon(LucideIcons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(storageService: widget.storageService),
                ),
              ).then((_) {
                if (_selectedFile != null) {
                  _processCurrentImage();
                } else {
                  setState(() {});
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _selectedFile == null ? _buildEmptyState() : _buildImageEditor(),
      ),
    );
  }
}
