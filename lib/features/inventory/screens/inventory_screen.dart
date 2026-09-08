import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'dart:convert';
import '../models/item.dart';
import '../models/shift_record.dart';
import '../models/entry_log.dart';
import '../../../core/database/database_helper.dart';
import 'shift_summary_screen.dart';
import '../../../core/storage/storage_service.dart';
import '../services/sync_service.dart';
import 'package:toastification/toastification.dart';

class InventoryScreen extends StatefulWidget {
  final StorageService storageService;
  final ShiftRecord shift;
  
  const InventoryScreen({Key? key, required this.storageService, required this.shift}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Item> _items = [];
  late ShiftRecord _currentShift;
  Map<int, List<EntryLog>> _entriesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentShift = widget.shift;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _items = await _db.getItems();
    
    final entries = await _db.getEntriesForShift(_currentShift.id!);
    _entriesMap.clear();
    for (var entry in entries) {
      if (!_entriesMap.containsKey(entry.itemId)) {
        _entriesMap[entry.itemId] = [];
      }
      _entriesMap[entry.itemId]!.add(entry);
    }

    setState(() => _isLoading = false);
  }

  void _editShiftName() {
    final titleController = TextEditingController(text: _currentShift.name);
    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Đổi Tên Ca'),
          closeIcon: const SizedBox.shrink(),
          description: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  controller: titleController,
                  placeholder: const Text('Tên ca'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton.outline(
                      child: const Text('Hủy'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      child: const Text('Lưu'),
                      onPressed: () async {
                        final newName = titleController.text.trim();
                        if (newName.isNotEmpty) {
                          _currentShift.name = newName;
                          await _db.updateShift(_currentShift);
                          setState(() {});
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _showInputDialog(Item item, [EntryLog? existingEntry, int? entryIndex]) {
    final valueController = TextEditingController(text: existingEntry?.enteredValue.toString() ?? '');
    String selectedUnit = existingEntry?.enteredUnit ?? item.baseUnit;

    showShadDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Map<String, String> availableUnits = {};
            availableUnits[item.baseUnit] = 'Nhập theo ${item.baseUnit}';
            
            if (item.customUnitsJson != '[]') {
              try {
                List<dynamic> parsed = jsonDecode(item.customUnitsJson);
                for (var u in parsed) {
                  availableUnits[u['name']] = 'Nhập theo ${u['name']}';
                }
              } catch (e) {}
            }
            if (!availableUnits.containsKey('P')) {
              availableUnits['P'] = 'Nhập theo Phần (P)';
            }

            return ShadDialog(
              title: Text(existingEntry == null ? 'Nhập: ${item.name}' : 'Sửa Lần Nhập $entryIndex'),
              closeIcon: const SizedBox.shrink(),
              description: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chọn đơn vị:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ShadSelect<String>(
                      initialValue: selectedUnit,
                      options: availableUnits.entries.map((e) {
                        return ShadOption(value: e.key, child: Text(e.value));
                      }).toList(),
                      selectedOptionBuilder: (context, value) => Text(availableUnits[value] ?? value),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedUnit = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    ShadInput(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      placeholder: Text('Giá trị ($selectedUnit)'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (existingEntry != null) ...[
                          ShadButton.destructive(
                            child: const Text('Xóa'),
                            onPressed: () async {
                              await _db.deleteEntry(existingEntry.id!);
                              _loadData();
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        ShadButton.outline(
                          child: const Text('Hủy'),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        ShadButton(
                          child: Text(existingEntry == null ? 'Thêm' : 'Lưu'),
                          onPressed: () async {
                            final valStr = valueController.text.replaceAll(',', '.');
                            final val = double.tryParse(valStr);
                            if (val != null && val > 0) {
                              if (existingEntry == null) {
                                final newEntry = EntryLog(
                                  shiftId: _currentShift.id!,
                                  itemId: item.id!,
                                  enteredValue: val,
                                  enteredUnit: selectedUnit,
                                  timestamp: DateTime.now().millisecondsSinceEpoch,
                                );
                                await _db.insertEntry(newEntry);
                              } else {
                                existingEntry.enteredValue = val;
                                existingEntry.enteredUnit = selectedUnit;
                                await _db.updateEntry(existingEntry);
                              }
                              _loadData();
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildEntriesWidgets(List<EntryLog> entries, Item item) {
    if (entries.isEmpty) {
      return const Text('Chưa nhập', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13));
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.asMap().entries.map((e) {
        int idx = e.key + 1;
        var log = e.value;
        String val = log.enteredValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        return ShadBadge(
          onPressed: () => _showInputDialog(item, log, idx),
          child: Text('L$idx: $val${log.enteredUnit}'),
        );
      }).toList(),
    );
  }

  @override
  void _showSnackBar(String message, {bool isError = false}) {
    toastification.show(
      context: context,
      type: isError ? ToastificationType.error : ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
    );
  }

  Future<void> _syncToTelegram() async {
    _showSnackBar('Đang đồng bộ lên Telegram...');
    bool success = await SyncService.syncShiftToTelegram(_currentShift);
    if (success) {
      final name = _currentShift.printTitle.trim().isNotEmpty ? _currentShift.printTitle : _currentShift.name;
      _showSnackBar('Đã lưu thành công: $name');
      setState(() {});
    } else {
      _showSnackBar('Đồng bộ thất bại. Hãy kiểm tra kết nối mạng hoặc thử nhắn 1 tin cho Bot.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _editShiftName,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentShift.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(LucideIcons.pencil, size: 16),
            ],
          ),
        ),
        actions: [
          ShadButton.ghost(
            child: const Icon(LucideIcons.cloudUpload),
            onPressed: _syncToTelegram,
          ),
          ShadButton.ghost(
            child: const Icon(LucideIcons.printer),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShiftSummaryScreen(
                    shift: _currentShift,
                    storageService: widget.storageService,
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ShadCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tiêu đề in (hiển thị trên bill):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ShadInput(
                      initialValue: _currentShift.printTitle,
                      placeholder: const Text('VD: Ca 1, Ca Sáng...'),
                      onChanged: (val) {
                        _currentShift.printTitle = val;
                        _db.updateShift(_currentShift);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          final item = _items[index - 1];
          final logs = _entriesMap[item.id] ?? [];
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GestureDetector(
              onTap: () => _showInputDialog(item),
              child: ShadCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        ShadBadge.secondary(
                          child: Text('${item.conversionRate.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}${item.baseUnit}/P'),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildEntriesWidgets(logs, item),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: ShadButton(
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(LucideIcons.check, size: 16),
            ),
            Text('Chốt Ca'),
          ],
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}
