import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:toastification/toastification.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/printing/network_scanner_service.dart';
import '../../inventory/screens/item_settings_screen.dart' as my_prinf_app_items;

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;

  const SettingsScreen({Key? key, required this.storageService}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _paperSizeController = TextEditingController();
  bool _isScanning = false;
  int _scanProgress = 0;
  int _scanTotal = 254;

  final NetworkScannerService _scannerService = NetworkScannerService();

  @override
  void initState() {
    super.initState();
    _ipController.text = widget.storageService.ipAddress;
    _portController.text = widget.storageService.port.toString();
    _paperSizeController.text = widget.storageService.paperSize;
  }

  void _saveSettings() {
    widget.storageService.setIpAddress(_ipController.text);
    final port = int.tryParse(_portController.text) ?? 9100;
    widget.storageService.setPort(port);
    widget.storageService.setPaperSize(_paperSizeController.text);

    _showSnackBar('Lưu cấu hình thành công!');
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

  Future<void> _scanNetwork() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0;
      _scanTotal = 254;
    });

    _showSnackBar('🔍 Đang quét mạng, vui lòng chờ...');

    try {
      final activePrinters = await _scannerService.scanForPrinters(
        onProgress: (scanned, total) {
          if (!mounted) return;
          setState(() {
            _scanProgress = scanned;
            _scanTotal = total;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanProgress = 0;
      });

      if (activePrinters.isEmpty) {
        _showSnackBar(
          'Không tìm thấy máy in nào.\nKiểm tra máy in có bật và cùng mạng WiFi không.',
          isError: true,
        );
      } else if (activePrinters.length == 1) {
        _ipController.text = activePrinters.first;
        _showSnackBar('✅ Đã tìm thấy máy in tại ${activePrinters.first}');
      } else {
        _showSnackBar('✅ Tìm thấy ${activePrinters.length} thiết bị, chọn máy in bên dưới.');
        _showPrinterSelectionDialog(activePrinters);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanProgress = 0;
      });

      final msg = e.toString().replaceFirst('Exception: ', '');
      _showSnackBar(msg, isError: true);
    }
  }

  void _showPrinterSelectionDialog(List<String> printers) {
    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Chọn máy in'),
          closeIcon: const SizedBox.shrink(),
          description: SizedBox(
            width: 340,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: printers.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _ipController.text = printers[index];
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF4F4F5))),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.printer, size: 20, color: Color(0xFF71717A)),
                        const SizedBox(width: 12),
                        Text(printers[index], style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            ShadButton.outline(
              child: const Text('Hủy'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: ShadCard(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Địa chỉ IP máy in'),
                        Row(
                          children: [
                            Expanded(
                              child: ShadInput(
                                controller: _ipController,
                                placeholder: const Text('Ví dụ: 192.168.1.100'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ShadButton.outline(
                              onPressed: _isScanning ? null : _scanNetwork,
                              child: _isScanning
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.searchCode, size: 14),
                                      SizedBox(width: 6),
                                      Text('Dò tìm', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                        if (_isScanning) ...[  
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: _scanTotal > 0 ? _scanProgress / _scanTotal : null,
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_scanProgress/$_scanTotal',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        
                        _buildLabel('Cổng (Port)'),
                        ShadInput(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          placeholder: const Text('Mặc định: 9100'),
                        ),
                        const SizedBox(height: 24),

                        _buildLabel('Khổ giấy (mm)'),
                        ShadInput(
                          controller: _paperSizeController,
                          keyboardType: TextInputType.number,
                          placeholder: const Text('Ví dụ: 58 hoặc 80'),
                        ),
                        const SizedBox(height: 24),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('Làm tròn phần lẻ (Dư)'),
                            ShadSwitch(
                              value: widget.storageService.enableRounding,
                              onChanged: (val) {
                                setState(() {
                                  widget.storageService.setEnableRounding(val);
                                });
                              },
                            ),
                          ],
                        ),
                        const Text(
                          'Khi bật, hệ thống sẽ tự động tách phần lẻ ra thành đơn vị gốc (Ví dụ: 4P 12g).',
                          style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLabel('Chế độ Tối (Dark Mode)'),
                            ShadSwitch(
                              value: widget.storageService.isDarkMode,
                              onChanged: (val) {
                                setState(() {
                                  widget.storageService.toggleDarkMode(val);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const my_prinf_app_items.ItemSettingsScreen(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                Icon(LucideIcons.packageCheck),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Text('Cài đặt món ăn & Định mức', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Icon(LucideIcons.chevronRight),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ShadButton(
                  onPressed: _saveSettings,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(LucideIcons.save, size: 20),
                      ),
                      Text('Lưu Cấu Hình'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _paperSizeController.dispose();
    super.dispose();
  }
}
