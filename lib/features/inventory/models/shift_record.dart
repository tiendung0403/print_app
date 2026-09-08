class ShiftRecord {
  int? id;
  String name; // VD: Kiểm đầu ca
  String printTitle; // Tiêu đề in
  int timestamp; // Ngày giờ tạo
  bool isSynced; // Trạng thái đồng bộ Telegram

  ShiftRecord({
    this.id,
    required this.name,
    this.printTitle = '',
    required this.timestamp,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'print_title': printTitle,
      'timestamp': timestamp,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ShiftRecord.fromMap(Map<String, dynamic> map) {
    return ShiftRecord(
      id: map['id'],
      name: map['name'],
      printTitle: map['print_title'] ?? '',
      timestamp: map['timestamp'],
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }
}
