import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;

  // Create a new record
  Future<Map<String, dynamic>> createRecord({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _supabase
          .from(table)
          .insert(data)
          .select()
          .single();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Create Record Error: ${e.message}');
    }
  }

  // Fetch all records from a table
  Future<List<Map<String, dynamic>>> fetchRecords({
    required String table,
    List<String>? columns,
    Map<String, dynamic>? filters,
  }) async {
    try {
      var query = _supabase.from(table).select(columns?.join(',') ?? '*');
      
      // Apply filters if provided
      if (filters != null) {
        filters.forEach((key, value) {
          query = query.eq(key, value);
        });
      }

      final response = await query;
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Fetch Records Error: ${e.message}');
    }
  }

  // Update a record
  Future<Map<String, dynamic>> updateRecord({
    required String table,
    required int id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _supabase
          .from(table)
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Update Record Error: ${e.message}');
    }
  }

  // Delete a record
  Future<void> deleteRecord({
    required String table,
    required int id,
  }) async {
    try {
      await _supabase
          .from(table)
          .delete()
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Delete Record Error: ${e.message}');
    }
  }

  // Real-time subscription example
  Stream<List<Map<String, dynamic>>> watchTable(String table) {
    return _supabase
        .from(table)
        .stream(primaryKey: ['id']);
  }
}
