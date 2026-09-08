class EntryLog {
  int? id;
  int shiftId;
  int itemId;
  double enteredValue; // Giá trị nhập
  String enteredUnit; // Đơn vị nhập ('P' hoặc baseUnit của item)
  int timestamp;

  EntryLog({
    this.id,
    required this.shiftId,
    required this.itemId,
    required this.enteredValue,
    required this.enteredUnit,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shift_id': shiftId,
      'item_id': itemId,
      'entered_value': enteredValue,
      'entered_unit': enteredUnit,
      'timestamp': timestamp,
    };
  }

  factory EntryLog.fromMap(Map<String, dynamic> map) {
    return EntryLog(
      id: map['id'],
      shiftId: map['shift_id'],
      itemId: map['item_id'],
      enteredValue: (map['entered_value'] as num).toDouble(),
      enteredUnit: map['entered_unit'],
      timestamp: map['timestamp'],
    );
  }
}
