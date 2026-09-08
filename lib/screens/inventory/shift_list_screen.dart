import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:intl/intl.dart';
import '../../models/shift_record.dart';
import '../../database/database_helper.dart';
import '../../services/storage_service.dart';
import 'inventory_screen.dart';

class ShiftListScreen extends StatefulWidget {
  final StorageService storageService;

  const ShiftListScreen({Key? key, required this.storageService}) : super(key: key);

  @override
  _ShiftListScreenState createState() => _ShiftListScreenState();
}

class _ShiftListScreenState extends State<ShiftListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<ShiftRecord> _shifts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    _shifts = await _db.getAllShifts();
    setState(() => _isLoading = false);
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Hôm qua';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  List<ShiftRecord> get _filteredShifts {
    return _shifts.where((s) {
      final nameMatches = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                          s.printTitle.toLowerCase().contains(_searchQuery.toLowerCase());
      bool dateMatches = true;
      if (_dateRange != null) {
        final d = DateTime.fromMillisecondsSinceEpoch(s.timestamp);
        final start = _dateRange!.start;
        // make end inclusive by going to end of the day
        final end = _dateRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
        dateMatches = d.isAfter(start) && d.isBefore(end);
      }
      return nameMatches && dateMatches;
    }).toList();
  }

  void _createNewShift() {
    final now = DateTime.now();
    
    // Find how many shifts exist today to auto-name
    int todayCount = 0;
    for (var shift in _shifts) {
      final d = DateTime.fromMillisecondsSinceEpoch(shift.timestamp);
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        todayCount++;
      }
    }
    
    final defaultName = 'Ca ${todayCount + 1} - ${now.day}/${now.month}';
    final controller = TextEditingController(text: defaultName);

    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Thêm Ca / Ghi Chú Mới'),
          closeIcon: const SizedBox.shrink(),
          description: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadInput(
                  controller: controller,
                  placeholder: const Text('Tiêu đề (VD: Ca sáng, Trả hàng...)'),
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
                      child: const Text('Tạo'),
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.pop(context);
                          final newShift = ShiftRecord(name: name, timestamp: now.millisecondsSinceEpoch);
                          final shiftId = await _db.insertShift(newShift);
                          newShift.id = shiftId;
                          _openShift(newShift);
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

  void _openShift(ShiftRecord shift) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryScreen(
          storageService: widget.storageService,
          shift: shift,
        ),
      ),
    ).then((_) => _loadShifts()); // Reload after coming back
  }

  void _deleteShift(ShiftRecord shift) {
    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Xác nhận xóa'),
          closeIcon: const SizedBox.shrink(),
          description: Text(shift.isSynced
            ? 'Ca này đã được sao lưu lên Cloud.\nBạn có chắc muốn xóa khỏi máy không?'
            : 'CẢNH BÁO: Ca này CHƯA ĐƯỢC SAO LƯU!\nXóa sẽ mất vĩnh viễn toàn bộ số liệu.\nBạn vẫn muốn xóa chứ?',
            style: TextStyle(color: shift.isSynced ? null : Colors.red, fontWeight: FontWeight.bold),
          ),
          actions: [
            ShadButton.outline(
              child: const Text('Hủy'),
              onPressed: () => Navigator.pop(context),
            ),
            ShadButton.destructive(
              child: const Text('Xóa'),
              onPressed: () async {
                await _db.deleteShift(shift.id!);
                _loadShifts();
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group shifts by date
    final filtered = _filteredShifts;
    final Map<String, List<ShiftRecord>> groupedShifts = {};
    for (var shift in filtered) {
      final dateStr = _formatDate(shift.timestamp);
      if (!groupedShifts.containsKey(dateStr)) {
        groupedShifts[dateStr] = [];
      }
      groupedShifts[dateStr]!.add(shift);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ Ghi Chú Ca', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    placeholder: const Text('Tìm kiếm tên ca...'),
                    leading: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(LucideIcons.search, size: 16),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  child: const Icon(LucideIcons.calendar, size: 20),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() {
                        _dateRange = picked;
                      });
                    }
                  },
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 8),
                  ShadButton.ghost(
                    child: const Icon(LucideIcons.x, size: 20, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                      });
                    },
                  )
                ]
              ],
            ),
          ),
          Expanded(
            child: groupedShifts.isEmpty
                ? const Center(child: Text('Không tìm thấy ca nào phù hợp.', style: TextStyle(color: Color(0xFFA1A1AA))))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
              itemCount: groupedShifts.length,
              itemBuilder: (context, index) {
                final dateStr = groupedShifts.keys.elementAt(index);
                final shiftsForDate = groupedShifts[dateStr]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Text(
                        dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF71717A)),
                      ),
                    ),
                    ...shiftsForDate.map((shift) {
                      final timeStr = DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(shift.timestamp));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GestureDetector(
                          onTap: () => _openShift(shift),
                          child: ShadCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(shift.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        if (shift.isSynced) ...[
                                          const SizedBox(width: 8),
                                          const Icon(LucideIcons.cloud, size: 16, color: Colors.blue),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Tạo lúc $timeStr', style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                                  ],
                                ),
                                ShadButton.ghost(
                                  child: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                                  onPressed: () => _deleteShift(shift),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ShadButton(
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(LucideIcons.plus, size: 16),
            ),
            Text('Tạo Ca Mới'),
          ],
        ),
        onPressed: _createNewShift,
      ),
    );
  }
}
