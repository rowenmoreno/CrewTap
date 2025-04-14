import 'package:supabase_flutter/supabase_flutter.dart';

class ApiHelper {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> findNearestAirport(double latitude, double longitude) async {
    try {
      final response = await _client.functions.invoke(
        'find-nearest-airport',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to fetch nearest airport: ${response.status}');
      }

      final data = response.data as List;
      if (data.isEmpty) {
        throw Exception('No airports found');
      }

      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Error finding nearest airport: $e');
    }
  }
}

