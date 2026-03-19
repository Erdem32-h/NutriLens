import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static late final SupabaseClient client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL is not set in .env file');
    }
    if (anonKey == null || anonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not set in .env file');
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    client = Supabase.instance.client;
  }
}
