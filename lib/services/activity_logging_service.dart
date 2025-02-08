import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'logging_diagnostics.dart';

enum ActivityType {
  login,
  logout,
  profileUpdate,
  orderCreated,
  orderUpdated,
  productViewed,
  productAdded,
  productUpdated
}

class ActivityLoggingService {
  static final _supabase = Supabase.instance.client;
  late final LoggingDiagnostics _diagnostics;

  ActivityLoggingService() {
    _diagnostics = LoggingDiagnostics(_supabase);
  }

  // Log user activity with comprehensive error handling
  Future<void> logActivity({
    required String userId,
    required ActivityType activityType,
    Map<String, dynamic>? additionalDetails,
  }) async {
    try {
      // Validate input
      if (userId.isEmpty) {
        print('❌ [ActivityLogging] Cannot log activity: User ID is empty');
        return;
      }

      // Prepare activity data with comprehensive information
      final activityData = {
        'user_id': userId,
        'activity_type': activityType.toString().split('.').last,
        'timestamp': DateTime.now().toIso8601String(),
        'details': additionalDetails != null ? _safeJsonEncode(additionalDetails) : null,
        'ip_address': await _getIpAddress(),
      };

      // Validate activity data
      if (activityData['activity_type'] == null) {
        print('❌ [ActivityLogging] Cannot log activity: Invalid activity type');
        return;
      }

      // Detailed pre-insert logging
      print('🔍 [ActivityLogging] Preparing to log activity:');
      print('User ID: $userId');
      print('Activity Type: ${activityData['activity_type']}');
      print('Timestamp: ${activityData['timestamp']}');
      print('Additional Details: ${activityData['details']}');

      // Insert activity log with comprehensive error handling
      final response = await _supabase
        .from('user_activities')
        .insert(activityData)
        .select();

      // Log successful insertion
      print('✅ [ActivityLogging] Activity logged successfully:');
      print('Inserted Record: $response');
    } on PostgrestException catch (e) {
      // Detailed Supabase error logging
      print('❌ [ActivityLogging] Supabase Error:');
      print('Message: ${e.message}');
      print('Code: ${e.code}');
      print('Details: ${e.details}');
      print('Hint: ${e.hint}');

      // Attempt to resolve common issues
      if (e.code == '42P01') {  // Undefined table
        await _diagnostics.createUserActivitiesTable();
        // Retry logging
        await _retryLoggingActivity(userId, activityType, additionalDetails);
      }

      // Additional error handling for common issues
      if (e.code == '23503') {
        print('⚠️ Foreign Key Constraint Violation: Ensure user exists');
      }
      if (e.code == '23505') {
        print('⚠️ Unique Constraint Violation');
      }
    } catch (e, stackTrace) {
      // Catch-all error logging
      print('❌ [ActivityLogging] Unexpected error:');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
    }
  }

  // Retry logging activity after potential table creation
  Future<void> _retryLoggingActivity(
    String userId, 
    ActivityType activityType, 
    Map<String, dynamic>? additionalDetails
  ) async {
    try {
      await logActivity(
        userId: userId, 
        activityType: activityType, 
        additionalDetails: additionalDetails
      );
    } catch (e) {
      print('❌ Retry logging failed: $e');
    }
  }

  // Run comprehensive diagnostics
  Future<void> runDiagnostics() async {
    try {
      final diagnosticResults = await _diagnostics.runCompleteDiagnostics();
      
      // If table doesn't exist, attempt to create it
      if (diagnosticResults['table_existence']['exists'] == false) {
        await _diagnostics.createUserActivitiesTable();
      }
    } catch (e) {
      print('Diagnostic check failed: $e');
    }
  }

  // Safe JSON encoding to prevent serialization errors
  String? _safeJsonEncode(Map<String, dynamic>? data) {
    try {
      return data != null ? jsonEncode(data) : null;
    } catch (e) {
      print('Error encoding JSON: $e');
      return null;
    }
  }

  // Helper method to get IP address with more robust implementation
  Future<String> _getIpAddress() async {
    try {
      // You can replace this with a more sophisticated IP detection method
      // For example, using a package like 'http' to fetch from an IP service
      return 'unknown';
    } catch (e) {
      print('Error getting IP address: $e');
      return 'unknown';
    }
  }

  // Fetch user activities
  Future<List<Map<String, dynamic>>> getUserActivities({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
        .from('user_activities')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false)
        .range(offset, offset + limit - 1);

      // Parse details from JSON string
      return response.map((activity) {
        if (activity['details'] != null) {
          activity['details'] = jsonDecode(activity['details']);
        }
        return activity;
      }).toList();
    } on PostgrestException catch (e) {
      print('Failed to fetch user activities: ${e.message}');
      return [];
    }
  }

  // Get recent system-wide activities
  Future<List<Map<String, dynamic>>> getRecentSystemActivities({
    int limit = 100,
  }) async {
    try {
      final response = await _supabase
        .from('user_activities')
        .select('*, users(name, email)')
        .order('timestamp', ascending: false)
        .limit(limit);

      return response;
    } on PostgrestException catch (e) {
      print('Failed to fetch system activities: ${e.message}');
      return [];
    }
  }

  // Delete old activity logs (for maintenance)
  Future<void> deleteOldActivityLogs({
    required int daysToKeep,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      await _supabase
        .from('user_activities')
        .delete()
        .lt('timestamp', cutoffDate.toIso8601String());
    } on PostgrestException catch (e) {
      print('Failed to delete old activity logs: ${e.message}');
    }
  }

  // Verify table configuration and Realtime settings
  Future<void> verifyTableConfiguration() async {
    try {
      // Check table existence and structure
      final tableInfo = await _supabase
        .rpc('get_table_info', params: {
          'table_name': 'user_activities',
          'schema_name': 'public'
        });

      print('Table Information:');
      print(tableInfo);

      // Check Realtime publication
      final realtimeInfo = await _supabase
        .rpc('get_realtime_publication_info');

      print('Realtime Publication Info:');
      print(realtimeInfo);

      // Perform a test insert to verify full functionality
      final testActivity = {
        'user_id': 'test-user-id',
        'activity_type': 'test_activity',
        'timestamp': DateTime.now().toIso8601String(),
        'details': null,
        'ip_address': 'test-ip'
      };

      final insertResponse = await _supabase
        .from('user_activities')
        .insert(testActivity)
        .select();

      print('Test Insert Response:');
      print(insertResponse);
    } on PostgrestException catch (e) {
      print('Verification Error:');
      print('Message: ${e.message}');
      print('Code: ${e.code}');
      print('Details: ${e.details}');
    } catch (e) {
      print('Unexpected verification error: $e');
    }
  }

  // Stream of recent system activities
  Stream<List<Map<String, dynamic>>> watchSystemActivities({
    int limit = 100,
  }) {
    return _supabase
      .from('user_activities')
      .stream(primaryKey: ['id'])
      .order('timestamp', ascending: false)
      .limit(limit);
  }

  // Verify and fix potential logging issues
  Future<void> diagnosticCheck(String userId) async {
    try {
      // Check user existence
      final userCheck = await _supabase
        .from('users')
        .select('id')
        .eq('id', userId)
        .single();

      print('✅ User Verification:');
      print('User exists: $userCheck');

      // Check table permissions
      final permissionCheck = await _supabase
        .rpc('check_table_permissions', params: {
          'table_name': 'user_activities'
        });

      print('🔐 Table Permissions:');
      print('Permission Check Result: $permissionCheck');

      // Attempt a test insert
      final testActivity = {
        'user_id': userId,
        'activity_type': 'diagnostic_check',
        'timestamp': DateTime.now().toIso8601String(),
        'details': {'diagnostic': 'system check'},
        'ip_address': 'diagnostic'
      };

      final testInsert = await _supabase
        .from('user_activities')
        .insert(testActivity)
        .select();

      print('🧪 Diagnostic Insert:');
      print('Test Insert Result: $testInsert');
    } catch (e) {
      print('❌ Diagnostic Check Failed:');
      print('Error: $e');
    }
  }
}

// SQL to create the user_activities table in Supabase
/*
CREATE TABLE public.user_activities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    details JSONB,
    ip_address TEXT
);

-- Optional: Create an index for faster queries
CREATE INDEX idx_user_activities_user_id ON public.user_activities(user_id);
CREATE INDEX idx_user_activities_timestamp ON public.user_activities(timestamp);
*/
