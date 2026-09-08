import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/shift_record.dart';
import '../models/item.dart';
import '../models/entry_log.dart';
import '../../../core/database/database_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SyncService {
  static String get botToken => dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '';
  static String chatId = dotenv.env['TELEGRAM_CHAT_ID'] ?? ''; 

  static Future<bool> syncShiftToTelegram(ShiftRecord shift) async {
    if (chatId.isEmpty) {
      // Thử tự động lấy chat_id nếu chưa có
      await fetchChatId();
      if (chatId.isEmpty) return false;
    }

    try {
      final db = DatabaseHelper.instance;
      final items = await db.getItems();
      final entries = await db.getEntriesForShift(shift.id!);

      if (entries.isEmpty) return false;

      // Xây dựng chuỗi văn bản báo cáo giống với bill in
      StringBuffer sb = StringBuffer();
      final printTitle = shift.printTitle.trim().isNotEmpty ? shift.printTitle : shift.name;
      
      sb.writeln('📦 BÁO CÁO KIỂM KHO');
      sb.writeln('🔖 Ca: $printTitle');
      sb.writeln('🕒 Thời gian: ${DateTime.fromMillisecondsSinceEpoch(shift.timestamp).toString().split('.')[0]}');
      sb.writeln('-----------------------------------');

      for (var item in items) {
        final itemLogs = entries.where((e) => e.itemId == item.id).toList();
        if (itemLogs.isEmpty) continue;

        Map<String, double> unitRates = { item.baseUnit: item.conversionRate };
        if (item.customUnitsJson != '[]') {
          try {
            List<dynamic> parsed = jsonDecode(item.customUnitsJson);
            for (var u in parsed) {
              unitRates[u['name']] = (u['rate'] as num).toDouble();
            }
          } catch (e) {}
        }

        double finalTotalPortions = 0.0;
        double totalBaseUnits = 0.0;

        for (var log in itemLogs) {
          if (log.enteredUnit == 'P') {
            finalTotalPortions += log.enteredValue;
            totalBaseUnits += (log.enteredValue * item.conversionRate);
          } else {
            double rate = unitRates[log.enteredUnit] ?? item.conversionRate;
            if (rate > 0) {
              finalTotalPortions += (log.enteredValue / rate);
              totalBaseUnits += (log.enteredValue / rate) * item.conversionRate;
            }
          }
        }

        String qtyStr = '${totalBaseUnits.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}${item.baseUnit}';
        
        int wholePortions = finalTotalPortions.floor();
        double remainderBaseUnits = (finalTotalPortions - wholePortions) * item.conversionRate;
        
        String resultStr = '';
        if (remainderBaseUnits > 0.01) {
          String remStr = remainderBaseUnits.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
          resultStr = '${wholePortions}P ${remStr}${item.baseUnit}';
        } else {
          resultStr = '${wholePortions}P';
        }

        sb.writeln('▪️ ${item.name}');
        sb.writeln('   Tổng lượng: $qtyStr');
        sb.writeln('   Quy đổi: $resultStr');
      }

      sb.writeln('-----------------------------------');
      sb.writeln('✅ Đã đồng bộ thành công!');

      // Send to Telegram
      final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': sb.toString(),
        }),
      );

      if (response.statusCode == 200) {
        // Cập nhật is_synced trong database
        shift.isSynced = true;
        await db.updateShift(shift);
        return true;
      } else {
        print('Telegram Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Sync Error: $e');
      return false;
    }
  }

  // Hàm hỗ trợ tự động lấy Chat ID từ tin nhắn mới nhất
  static Future<void> fetchChatId() async {
    try {
      final url = Uri.parse('https://api.telegram.org/bot$botToken/getUpdates');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true && (data['result'] as List).isNotEmpty) {
          final results = data['result'] as List;
          // Lấy tin nhắn cuối cùng để lấy chat_id
          final lastMessage = results.last['message'];
          if (lastMessage != null && lastMessage['chat'] != null) {
            chatId = lastMessage['chat']['id'].toString();
          }
        }
      }
    } catch (e) {
      print('Fetch Chat ID Error: $e');
    }
  }
}
