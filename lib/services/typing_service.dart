import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/typing_event.dart';

import '../services/supabase_service.dart';

class TypingService {
  static String get typingTable => SupabaseService.isDev ? 'chat_typing_dev' : 'chat_typing';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> sendTypingEvent(TypingEvent event) async {
    await client.from(typingTable).upsert(event.toJson());
  }

  static Stream<List<TypingEvent>> subscribeToTypingEvents(String chatId) {
    return client
      .from('$typingTable:chat_id=eq.$chatId')
      .stream(primaryKey: ['chat_id', 'user_id'])
      .map((events) {
        return events.map((e) => TypingEvent.fromJson(e)).toList();
      });
  }
}
