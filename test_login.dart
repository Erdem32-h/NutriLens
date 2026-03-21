import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://jhcgfhbaafkhbftmndpi.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpoY2dmaGJhYWZraGJmdG1uZHBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwNDExOTQsImV4cCI6MjA4OTYxNzE5NH0.846w-By6HJ8PSRzSBdXV6VhIPWu2erL8brClCg4JpG8';
  
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    print('Attempting login with test account...');
    final response = await client.auth.signInWithPassword(
      email: 'test@nutrilens.com',
      password: 'password123',
    );
    print('Login successful: ${response.user?.id}');
  } on AuthException catch (e) {
    print('Auth Error Code: ${e.statusCode}');
    print('Auth Error Message: ${e.message}');
  } catch (e) {
    print('Unknown error: $e');
  }
}
