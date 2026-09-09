import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../features/inventory/models/item.dart';
import '../../features/inventory/models/shift_record.dart';
import '../../features/inventory/models/entry_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute("ALTER TABLE items ADD COLUMN custom_units TEXT DEFAULT '[]'");
          } catch (e) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE shifts ADD COLUMN print_title TEXT DEFAULT ''");
          } catch (e) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute("ALTER TABLE shifts ADD COLUMN is_synced INTEGER DEFAULT 0");
          } catch (e) {}
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        base_unit TEXT NOT NULL,
        conversion_rate REAL NOT NULL,
        custom_units TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        print_title TEXT NOT NULL DEFAULT '',
        is_synced INTEGER NOT NULL DEFAULT 0,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        entered_value REAL NOT NULL,
        entered_unit TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');
    
    // Seed data
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final initialItems = [
      {'name': 'Bò', 'base_unit': 'g', 'conversion_rate': 33.0},
      {'name': 'Cá Hồi Chiên', 'base_unit': 'g', 'conversion_rate': 30.0},
      {'name': 'Cá Hồi Tươi', 'base_unit': 'g', 'conversion_rate': 25.0},
      {'name': 'Cá Ngừ', 'base_unit': 'g', 'conversion_rate': 30.0},
      {'name': 'Cá Trích', 'base_unit': 'g', 'conversion_rate': 22.5},
      {'name': 'Chả Giò', 'base_unit': 'P', 'conversion_rate': 1.0},
      {'name': 'Cốt Lết', 'base_unit': 'g', 'conversion_rate': 30.0},
      {'name': 'Gà', 'base_unit': 'g', 'conversion_rate': 33.0},
      {'name': 'Lạp Xưởng', 'base_unit': 'cây', 'conversion_rate': 1.0},
      {'name': 'Lươn', 'base_unit': 'g', 'conversion_rate': 25.0},
      {'name': 'Thanh Cua', 'base_unit': 'thanh', 'conversion_rate': 1.0},
      {'name': 'Tôm Chiên', 'base_unit': 'con', 'conversion_rate': 1.0}, // User will update this later
      {'name': 'Trứng', 'base_unit': 'g', 'conversion_rate': 45.0},
      {'name': 'Xúc Xích', 'base_unit': 'cây', 'conversion_rate': 1.0},
    ];

    for (var item in initialItems) {
      await db.insert('items', item);
    }
  }

  // --- Item Methods ---
  Future<List<Item>> getItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'name ASC');
    return result.map((json) => Item.fromMap(json)).toList();
  }

  Future<int> insertItem(Item item) async {
    final db = await instance.database;
    return await db.insert('items', item.toMap());
  }

  Future<int> updateItem(Item item) async {
    final db = await instance.database;
    return await db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<List<ShiftRecord>> getAllShifts() async {
    final db = await instance.database;
    final result = await db.query('shifts', orderBy: 'timestamp DESC');
    return result.map((json) => ShiftRecord.fromMap(json)).toList();
  }

  Future<int> updateShift(ShiftRecord shift) async {
    final db = await instance.database;
    return await db.update('shifts', shift.toMap(), where: 'id = ?', whereArgs: [shift.id]);
  }

  Future<int> deleteShift(int id) async {
    final db = await instance.database;
    return await db.delete('shifts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // --- Shift Methods ---
  Future<ShiftRecord?> getLatestShift() async {
    final db = await instance.database;
    final result = await db.query('shifts', orderBy: 'timestamp DESC', limit: 1);
    if (result.isNotEmpty) {
      return ShiftRecord.fromMap(result.first);
    }
    return null;
  }

  Future<int> insertShift(ShiftRecord shift) async {
    final db = await instance.database;
    return await db.insert('shifts', shift.toMap());
  }

  // --- Entry Methods ---
  Future<int> insertEntry(EntryLog entry) async {
    final db = await instance.database;
    return await db.insert('entries', entry.toMap());
  }

  Future<List<EntryLog>> getEntriesForShiftAndItem(int shiftId, int itemId) async {
    final db = await instance.database;
    final result = await db.query('entries', where: 'shift_id = ? AND item_id = ?', whereArgs: [shiftId, itemId], orderBy: 'timestamp ASC');
    return result.map((json) => EntryLog.fromMap(json)).toList();
  }
  
  Future<bool> hasEntriesForItem(int itemId) async {
    final db = await instance.database;
    final result = await db.query('entries', where: 'item_id = ?', whereArgs: [itemId], limit: 1);
    return result.isNotEmpty;
  }
  
  Future<List<EntryLog>> getEntriesForShift(int shiftId) async {
    final db = await instance.database;
    final result = await db.query('entries', where: 'shift_id = ?', whereArgs: [shiftId]);
    return result.map((json) => EntryLog.fromMap(json)).toList();
  }

  Future<int> updateEntry(EntryLog entry) async {
    final db = await instance.database;
    return await db.update('entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteEntry(int id) async {
    final db = await instance.database;
    return await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- Backup & Restore Methods ---
  
  /// Xuất toàn bộ dữ liệu ra định dạng JSON string
  Future<String> exportDataToJson() async {
    final db = await instance.database;
    final items = await db.query('items');
    final shifts = await db.query('shifts');
    final entries = await db.query('entries');

    final data = {
      'version': 1,
      'export_time': DateTime.now().toIso8601String(),
      'items': items,
      'shifts': shifts,
      'entries': entries,
    };

    return jsonEncode(data);
  }

  /// Khôi phục toàn bộ dữ liệu từ JSON string (ghi đè toàn bộ)
  Future<void> importDataFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    if (!data.containsKey('items') || !data.containsKey('shifts') || !data.containsKey('entries')) {
      throw FormatException('File backup không đúng định dạng hoặc bị lỗi.');
    }

    final db = await instance.database;
    
    // Sử dụng transaction để đảm bảo toàn vẹn dữ liệu
    await db.transaction((txn) async {
      // 1. Xóa sạch dữ liệu cũ
      await txn.delete('entries');
      await txn.delete('shifts');
      await txn.delete('items');

      // 2. Chèn dữ liệu mới
      final items = data['items'] as List;
      for (var item in items) {
        await txn.insert('items', Map<String, dynamic>.from(item));
      }

      final shifts = data['shifts'] as List;
      for (var shift in shifts) {
        await txn.insert('shifts', Map<String, dynamic>.from(shift));
      }

      final entries = data['entries'] as List;
      for (var entry in entries) {
        await txn.insert('entries', Map<String, dynamic>.from(entry));
      }
    });
  }
}
