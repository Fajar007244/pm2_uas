import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class LoggingDiagnostics {
  final SupabaseClient _supabase;

  LoggingDiagnostics(this._supabase);

  // Comprehensive logging diagnostic report
  Future<Map<String, dynamic>> runCompleteDiagnostics() async {
    final diagnosticResults = {
      'timestamp': DateTime.now().toIso8601String(),
      'supabase_connection': await _checkSupabaseConnection(),
      'table_existence': await _checkTableExistence(),
      'table_permissions': await _checkTablePermissions(),
      'insert_test': await _performInsertTest(),
      'current_user': _getCurrentUserInfo(),
    };

    // Print detailed diagnostic information
    _printDiagnosticReport(diagnosticResults);

    return diagnosticResults;
  }

  // Check Supabase connection
  Future<Map<String, dynamic>> _checkSupabaseConnection() async {
    try {
      final connectionInfo = {
        'status': 'connected',
        'client_url': _supabase.supabaseUrl,
      };
      return connectionInfo;
    } catch (e) {
      return {
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  // Check if user_activities table exists
  Future<Map<String, dynamic>> _checkTableExistence() async {
    try {
      final response = await _supabase.rpc('check_table_exists',
          params: {'table_name': 'user_activities', 'schema_name': 'public'});

      return {
        'exists': response == true,
        'details': response.toString(),
      };
    } catch (e) {
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  // Check table permissions
  Future<Map<String, dynamic>> _checkTablePermissions() async {
    try {
      final response = await _supabase.rpc('check_table_permissions',
          params: {'table_name': 'user_activities'});

      return {
        'has_permissions': response == true,
        'details': response.toString(),
      };
    } catch (e) {
      return {
        'has_permissions': false,
        'error': e.toString(),
      };
    }
  }

  // Perform a test insert
  Future<Map<String, dynamic>> _performInsertTest() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'insert_status': 'skipped',
          'reason': 'No current user',
        };
      }

      final testActivity = {
        'user_id': currentUser.id,
        'activity_type': 'diagnostic_test',
        'timestamp': DateTime.now().toIso8601String(),
        'details': jsonEncode({
          'diagnostic': 'system check',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        'ip_address': 'diagnostic_test'
      };

      final insertResponse =
          await _supabase.from('user_activities').insert(testActivity).select();

      return {
        'insert_status': 'success',
        'inserted_id':
            insertResponse.isNotEmpty ? insertResponse[0]['id'] : null,
      };
    } catch (e) {
      return {
        'insert_status': 'failed',
        'error': e.toString(),
      };
    }
  }

  // Get current user information
  Map<String, dynamic> _getCurrentUserInfo() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      return {
        'user_status': 'not_logged_in',
      };
    }

    return {
      'user_status': 'logged_in',
      'user_id': currentUser.id,
      'email': currentUser.email,
    };
  }

  // Print detailed diagnostic report
  void _printDiagnosticReport(Map<String, dynamic> results) {
    print('=== Logging Diagnostics Report ===');
    print('Timestamp: ${results['timestamp']}');

    print('\n1. Supabase Connection:');
    print(jsonEncode(results['supabase_connection']));

    print('\n2. Table Existence:');
    print(jsonEncode(results['table_existence']));

    print('\n3. Table Permissions:');
    print(jsonEncode(results['table_permissions']));

    print('\n4. Insert Test:');
    print(jsonEncode(results['insert_test']));

    print('\n5. Current User:');
    print(jsonEncode(results['current_user']));

    print('\n=== End of Diagnostic Report ===');
  }

  // Create the user_activities table if it doesn't exist
  Future<void> createUserActivitiesTable() async {
    try {
      await _supabase.rpc('create_user_activities_table');
      print('User activities table created successfully');
    } catch (e) {
      print('Failed to create user activities table: $e');
    }
  }
}

extension on SupabaseClient {
  get supabaseUrl => null;
}

// Recommended SQL to add to Supabase edge functions or database migrations
/*
-- Function to check if table exists
CREATE OR REPLACE FUNCTION check_table_exists(table_name TEXT, schema_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = schema_name 
    AND table_name = table_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check table permissions
CREATE OR REPLACE FUNCTION check_table_permissions(table_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM information_schema.role_table_grants 
    WHERE table_name = table_name 
    AND privilege_type IN ('INSERT', 'SELECT')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create user_activities table
CREATE OR REPLACE FUNCTION create_user_activities_table()
RETURNS VOID AS $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.user_activities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    details JSONB,
    ip_address TEXT
  );

  -- Grant necessary permissions
  GRANT INSERT, SELECT ON public.user_activities TO authenticated;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
*/
