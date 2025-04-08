import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;

  // Auth operations
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.session == null) {
      throw 'Authentication failed';
    }
    
    return response;
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.session == null && response.user == null) {
      throw 'Registration failed';
    }
    
    return response;
  }

  static Future<void> signOut() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw 'No active session';
    }
    await _client.auth.signOut();
  }

  // Profile operations
  static Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw 'No active session';
    }
    
    await _client
        .from('profiles')
        .update(data)
        .eq('id', userId);
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw 'No active session';
    }
    
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  // Airlines operations
  static Future<List<Map<String, dynamic>>> getAirlines() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw 'No active session';
    }
    
    final response = await _client
        .from('airlines')
        .select('id, name')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Connection operations
  static Future<void> createConnection({
    required String userId,
    required String connectedUserId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw 'No active session';
    }
    
    await _client.from('connections').insert({
      'user_id': userId,
      'connected_user_id': connectedUserId,
      'status': 'pending',
    });
  }

  static Future<List<Map<String, dynamic>>> getConnections(String userId) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw 'No active session';
    }
    
    final response = await _client
        .from('connections')
        .select('*, profiles!connected_user_id(*)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }
} 