import 'package:supabase_flutter/supabase_flutter.dart';

class SoftDeleteService {
  final supabase = Supabase.instance.client;

  /// Soft delete an item from a specific table
  Future<bool> softDelete({
    required String tableName, 
    required String idColumn, 
    required dynamic itemId,
  }) async {
    try {
      await supabase
          .from(tableName)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq(idColumn, itemId);
      return true;
    } catch (e) {
      print('Soft delete error: $e');
      return false;
    }
  }

  /// Restore a soft-deleted item
  Future<bool> restoreItem({
    required String tableName, 
    required String idColumn, 
    required dynamic itemId,
  }) async {
    try {
      await supabase
          .from(tableName)
          .update({'deleted_at': null})
          .eq(idColumn, itemId);
      return true;
    } catch (e) {
      print('Restore item error: $e');
      return false;
    }
  }

  /// Query to exclude soft-deleted items
  PostgrestFilterBuilder excludeSoftDeleted(
    PostgrestFilterBuilder query,
  ) {
    return query.is_('deleted_at', null);
  }
}
