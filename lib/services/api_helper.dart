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

  Future<String?> getAirportPasscode(String airportCode) async {
    try {
      final response = await _client
          .from('airport_passcodes')
          .select('passcode')
          .eq('airport_code', airportCode)
          .single();

      return response['passcode'] as String?;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null; // No passcode found
      }
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching airport passcode: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllAirports() async {
    try {
      final response = await _client
          .from('airports')
          .select('airport_code, airport_name')
          .order('airport_name');

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching airports: $e');
    }
  }

  Future<Map<String, dynamic>> updateAirportPasscode(String airportCode, String passcode) async {
    try {
      final response = await _client
          .from('airport_passcodes')
          .upsert(
            {
              'airport_code': airportCode,
              'passcode': passcode,
            },
            onConflict: 'airport_code',
          )
          .select()
          .single();

      return {
        'message': 'Passcode updated successfully for $airportCode',
        'data': response,
      };
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Error updating airport passcode: $e');
    }
  }
}

