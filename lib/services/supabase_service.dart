import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseClient _client = SupabaseClient(
    SupabaseConfig.url,
    SupabaseConfig.anonKey,
  );

  static SupabaseClient get client => _client;

  // Auth operations
  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Profile operations
  static Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _client
        .from('profiles')
        .update(data)
        .eq('id', userId);
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  // Connection operations
  static Future<void> createConnection({
    required String userId,
    required String connectedUserId,
  }) async {
    await _client.from('connections').insert({
      'user_id': userId,
      'connected_user_id': connectedUserId,
      'status': 'pending',
    });
  }

  static Future<List<Map<String, dynamic>>> getConnections(String userId) async {
    final response = await _client
        .from('connections')
        .select('*, profiles!connected_user_id(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }
} 