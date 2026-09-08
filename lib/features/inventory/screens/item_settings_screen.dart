import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:toastification/toastification.dart';
import '../models/item.dart';
import '../../../core/database/database_helper.dart';

class ItemSettingsScreen extends StatefulWidget {
  const ItemSettingsScreen({Key? key}) : super(key: key);

  @override
  _ItemSettingsScreenState createState() => _ItemSettingsScreenState();
}

class _ItemSettingsScreenState extends State<ItemSettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Item> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    _items = await _db.getItems();
    setState(() => _isLoading = false);
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

  void _showItemDialog([Item? item, bool hasEntries = false]) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final baseUnitController = TextEditingController(text: item?.baseUnit ?? 'g');
    final conversionRateController = TextEditingController(text: item?.conversionRate.toString() ?? '1');
    
    List<Map<String, dynamic>> customUnits = [];
    if (item != null && item.customUnitsJson.isNotEmpty && item.customUnitsJson != '[]') {
      try {
        customUnits = List<Map<String, dynamic>>.from(jsonDecode(item.customUnitsJson));
      } catch (e) {
        customUnits = [];
      }
    }

    showShadDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ShadDialog(
              title: Text(item == null ? 'Thêm Món Mới' : 'Sửa Món'),
              closeIcon: const SizedBox.shrink(),
              description: SizedBox(
                width: 340,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ShadInput(
                      controller: nameController,
                      placeholder: const Text('Tên món (VD: Cá Trích)'),
                      enabled: !hasEntries,
                    ),
                    if (hasEntries)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0, bottom: 8.0),
                        child: Text('Món đã có số liệu nên không thể đổi tên', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    const Text('Đơn vị mặc định:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ShadInput(
                            controller: conversionRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            placeholder: const Text('Số lượng'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: ShadInput(
                            controller: baseUnitController,
                            placeholder: const Text('Tên Đơn Vị'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text('= 1 P'),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text('Các đơn vị khác (Tùy chọn):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...customUnits.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Map<String, dynamic> unit = entry.value;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ShadInput(
                                initialValue: unit['rate']?.toString() ?? '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                placeholder: const Text('Số lượng'),
                                onChanged: (val) => unit['rate'] = double.tryParse(val.replaceAll(',', '.')) ?? 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: ShadInput(
                                initialValue: unit['name'] ?? '',
                                placeholder: const Text('Đơn Vị'),
                                onChanged: (val) => unit['name'] = val,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text('= 1 P'),
                            ),
                            ShadButton.ghost(
                              child: const Icon(LucideIcons.minusCircle, color: Colors.red),
                              onPressed: () {
                                setDialogState(() {
                                  customUnits.removeAt(idx);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    }).toList(),
                    Row(
                      children: [
                        ShadButton.outline(
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(LucideIcons.plus, size: 16),
                              ),
                              Text('Thêm đơn vị khác'),
                            ],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              customUnits.add({'name': '', 'rate': 1.0});
                            });
                          },
                        ),
                      ],
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
                            final name = nameController.text.trim();
                            final baseUnit = baseUnitController.text.trim();
                            final rate = double.tryParse(conversionRateController.text.replaceAll(',', '.')) ?? 1.0;
                            
                            // Filter out empty custom units
                            final validCustomUnits = customUnits.where((u) => (u['name'] as String).trim().isNotEmpty && (u['rate'] as num) > 0).toList();
                            final customUnitsJson = jsonEncode(validCustomUnits);
                            
                            if (name.isNotEmpty && baseUnit.isNotEmpty && rate > 0) {
                              if (item == null) {
                                await _db.insertItem(Item(
                                  name: name, 
                                  baseUnit: baseUnit, 
                                  conversionRate: rate,
                                  customUnitsJson: customUnitsJson
                                ));
                              } else {
                                item.name = name;
                                item.baseUnit = baseUnit;
                                item.conversionRate = rate;
                                item.customUnitsJson = customUnitsJson;
                                await _db.updateItem(item);
                              }
                              _loadItems();
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

  void _deleteItem(Item item) {
    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Xác nhận xóa'),
          closeIcon: const SizedBox.shrink(),
          description: Text('Bạn có chắc muốn xóa món "${item.name}" không?'),
          actions: [
            ShadButton.outline(
              child: const Text('Hủy'),
              onPressed: () => Navigator.pop(context),
            ),
            ShadButton.destructive(
              child: const Text('Xóa'),
              onPressed: () async {
                await _db.deleteItem(item.id!);
                _loadItems();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt Món Ăn', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                
                String customUnitsDisplay = '';
                if (item.customUnitsJson != '[]') {
                  try {
                    List<dynamic> parsed = jsonDecode(item.customUnitsJson);
                    customUnitsDisplay = parsed.map((e) => '${e['rate']} ${e['name']} = 1P').join(', ');
                  } catch (e) {}
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Mặc định: ${item.conversionRate} ${item.baseUnit} = 1P', style: const TextStyle(color: Color(0xFF71717A))),
                            if (customUnitsDisplay.isNotEmpty)
                              Text('Khác: $customUnitsDisplay', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            ShadButton.ghost(
                              child: const Icon(LucideIcons.pencil, size: 20),
                              onPressed: () async {
                                bool hasEntries = await _db.hasEntriesForItem(item.id!);
                                _showItemDialog(item, hasEntries);
                              },
                            ),
                            ShadButton.ghost(
                              child: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                              onPressed: () async {
                                if (await _db.hasEntriesForItem(item.id!)) {
                                  _showSnackBar('Không thể xóa: Món này đã phát sinh số liệu!', isError: true);
                                  return;
                                }
                                _deleteItem(item);
                              },
                            ),
                          ],
                        )
                      ],
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
              child: Icon(LucideIcons.plus, size: 16),
            ),
            Text('Thêm Món'),
          ],
        ),
        onPressed: () => _showItemDialog(),
      ),
    );
  }
}
