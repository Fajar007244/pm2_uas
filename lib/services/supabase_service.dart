import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import 'package:logger/logger.dart';

class SupabaseService {
  // Create a logger instance
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  static late SupabaseClient _client;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: 'https://ozllkmkouqbjteayjcyy.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96bGxrbWtvdXFianRlYXlqY3l5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQzMTEyMzksImV4cCI6MjA0OTg4NzIzOX0.rokQhez1jcjeBxSF2vzum9SLw0y9KPEOB9MnCRyZsX4', // Replace with new key from Supabase dashboard
        debug: kDebugMode,
      );

      _client = Supabase.instance.client;
    } catch (e) {
      // Log initialization error
      _logger.e('Supabase Initialization Error', error: e);
      rethrow;
    }
  }

  static SupabaseClient get client => _client;

  /// Flexible query method with enhanced relationship handling
  static Future<dynamic> safeQuery({
    required String table,
    Map<String, dynamic>? filter,
    String? select,
    bool single = false,
    List<String>? orderBy,
  }) async {
    try {
      // Remove null values from filter
      filter = filter?.removeNullValues();

      // Validate filter keys if filter is not null
      if (filter != null) {
        filter = await _getValidFilterKeys(table, filter);
      }

      // Construct the base query with explicit columns
      PostgrestFilterBuilder query = _client.from(table).select(select ?? '*');

      // Apply filter if not empty
      if (filter != null && filter.isNotEmpty) {
        filter.forEach((key, value) {
          // Specific handling for ID columns and complex filtering
          if (key.endsWith('_id') && value is String) {
            _logger.w('Filtering by ID: $key');
            query = query.eq(key, value);
          } else if (value is List) {
            // Handle multiple filter conditions for the same key
            query = query.in_(key, value);
          } else {
            query = query.eq(key, value);
          }
        });
      }

      // Apply ordering
      if (orderBy != null && orderBy.isNotEmpty) {
        for (var column in orderBy) {
          query =
              query.order(column, ascending: false) as PostgrestFilterBuilder;
        }
      } else if (await _columnExists(table, 'created_at')) {
        // Default ordering by created_at if exists
        query = query.order('created_at', ascending: false)
            as PostgrestFilterBuilder;
      }

      // Execute query with error handling
      final response = await query.then((result) {
        if (single && result is List && result.length > 1) {
          _logger.w('Multiple rows returned for single query on $table');
          return result.first; // Return first row if multiple rows
        }
        return result;
      }).catchError((error) {
        _logger.e('Error in safeQuery for table $table', error: error);
        throw error; // Rethrow to be caught by the outer try-catch
      });

      return response;
    } catch (e, stackTrace) {
      _logger.e('Comprehensive error in safeQuery for table $table',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Validate and clean filter keys
  static Future<Map<String, dynamic>> _getValidFilterKeys(
      String table, Map<String, dynamic> originalFilter) async {
    final validColumns = await _inspectTableSchema(table);

    return Map.fromEntries(originalFilter.entries.where((entry) {
      final isValidColumn = validColumns.contains(entry.key);
      if (!isValidColumn) {
        _logger.w('Invalid column for $table: ${entry.key}');
      }
      return isValidColumn && entry.value != null;
    }));
  }

  /// Comprehensive table schema inspection
  static Future<List<String>> _inspectTableSchema(String table) async {
    try {
      // Predefined schemas for known tables
      final predefinedSchemas = {
        'orders': [
          'id',
          'user_id',
          'total_price',
          'status',
          'created_at',
          'updated_at'
        ],
        'order_items': [
          'id',
          'order_id',
          'product_id',
          'quantity',
          'deleted_at'
        ],
        'products': [
          'id',
          'name',
          'price',
          'image_path',
          'description',
          'category_id'
        ],
      };

      // Return predefined schema if available
      if (predefinedSchemas.containsKey(table)) {
        return predefinedSchemas[table]!;
      }

      // Fallback to dynamic schema inspection
      await _client.from(table).select(
          'id', const FetchOptions(head: true, count: CountOption.exact));

      // If no exception, assume the table exists
      return ['id'];
    } catch (e) {
      _logger.e('Error inspecting table schema for $table', error: e);
      return [];
    }
  }

  /// Check if a column exists in a table
  static Future<bool> _columnExists(String table, String columnName) async {
    final schema = await _inspectTableSchema(table);
    return schema.contains(columnName);
  }

  /// Public method to inspect and log table schema
  static Future<void> inspectTableSchema(String tableName) async {
    try {
      // Get table columns
      final columns = await _inspectTableSchema(tableName);

      // Log table columns
      _logger.d('Table: $tableName');
      _logger.d('Columns: $columns');
    } catch (e, stackTrace) {
      _logger.e('Error in public inspectTableSchema for $tableName',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Safe update method with improved error handling
  static Future<dynamic> safeUpdate({
    required String table,
    required Map<String, dynamic> data,
    required Map<String, dynamic> filter,
  }) async {
    try {
      // Validate and clean data and filter
      final cleanData = data.removeNullValues();
      final validFilter = await _getValidFilterKeys(table, filter);

      // Perform update
      final query = _client.from(table).update(cleanData).match(validFilter);

      return await _executeQuery(query, false, isUpdate: true);
    } catch (e, stackTrace) {
      _logger.e('Error updating $table', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Robust insert method with improved error handling
  static Future<dynamic> safeInsert({
    required String table,
    required Map<String, dynamic> data,
    bool upsert = false,
    bool returnMinimal = false,
  }) async {
    try {
      var query = _client.from(table).insert(data);

      // Fetch results with custom headers
      final response = await _executeQuery(
        query,
        !returnMinimal,
        isInsert: true,
      );

      return response;
    } on PostgrestException catch (e) {
      // Log detailed Supabase-specific error
      _logger.e('Supabase Insert Error',
          error: e.message, stackTrace: StackTrace.current);
      rethrow;
    } catch (e) {
      // Log generic errors
      _logger.e('Generic Insert Error',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  /// Helper method to execute query with appropriate headers and single/multiple result handling
  static Future<dynamic> _executeQuery(
    dynamic query,
    bool single, {
    bool isInsert = false,
    bool isUpdate = false,
  }) async {
    try {
      // Validate query object
      if (query == null) {
        throw Exception('Query cannot be null');
      }

      // Log query type for debugging
      _logger.d('Query Type: ${query.runtimeType}');

      // Execute query based on type and single/multiple result requirement
      if (query is PostgrestFilterBuilder) {
        return single ? await query.single() : await query;
      } else if (query is PostgrestTransformBuilder) {
        return single ? await query.single() : await query;
      } else {
        // Attempt generic execution for unknown types
        _logger.w('Unexpected query type: ${query.runtimeType}');

        // Fallback execution
        return single ? await query.single() : await query;
      }
    } on PostgrestException catch (e) {
      // Handle specific Supabase query exceptions
      if (e.code == 'PGRST116' && single) {
        // No rows returned for a single query
        _logger.w('No rows found for single query', error: e);
        return null;
      }
      rethrow;
    } catch (e, stackTrace) {
      // Comprehensive error logging
      _logger.e('Query execution error', error: e, stackTrace: stackTrace);

      // Rethrow to allow caller to handle specific errors
      rethrow;
    }
  }

  /// Diagnostic method to test query with multiple column variations
  static Future<dynamic> diagnosticQuery({
    required String table,
    Map<String, dynamic>? filter,
    String select = '*',
    bool single = false,
  }) async {
    _logger.d('Starting Diagnostic Query');
    _logger.d('Table: $table');
    _logger.d('Filter: $filter');
    _logger.d('Select: $select');

    // List of potential column name variations
    final columnVariations = [
      filter ?? {},
      {
        'user_id': filter?['user_id'],
        'order_id': filter?['user_id'],
        'id': filter?['user_id']
      },
      {
        'status': filter?['status'],
        'order_status': filter?['status'],
        'state': filter?['status']
      }
    ];

    for (var potentialFilter in columnVariations) {
      try {
        _logger.d('Attempting query with filter: $potentialFilter');

        PostgrestFilterBuilder query = _client.from(table).select(select);

        // Apply filters dynamically
        potentialFilter.forEach((key, value) {
          if (value != null) {
            query = query.eq(key, value);
          }
        });

        final response = single ? await query.single() : await query;

        _logger.d('Query Successful');
        _logger.d('Response: $response');

        return response;
      } catch (e) {
        _logger.w('Query failed with filter: $potentialFilter', error: e);
      }
    }

    throw Exception('All diagnostic query attempts failed');
  }

  /// Comprehensive database schema diagnostic method
  static Future<void> diagnosticDatabaseSchema() async {
    _logger.d('Starting Comprehensive Database Schema Diagnostic');

    // List of tables to inspect
    final tablesToInspect = ['users', 'orders', 'order_items', 'products'];

    for (var tableName in tablesToInspect) {
      await inspectTableSchema(tableName);
    }

    _logger.d('Database Schema Diagnostic Complete');
  }

  /// Perform a safe delete operation with error handling
  static Future<dynamic> safeDelete({
    required String table,
    required Map<String, dynamic> filter,
  }) async {
    try {
      // Validate filter keys
      filter = await _getValidFilterKeys(table, filter);

      // Perform delete operation
      final response = await _client
          .from(table)
          .delete()
          .match(filter)
          .then((value) => value);

      return response;
    } catch (e, stackTrace) {
      _logger.e('Error in safeDelete for $table',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

// Extension method to remove null values from maps
extension MapUtils on Map<String, dynamic> {
  Map<String, dynamic> removeNullValues() {
    return Map.fromEntries(entries.where((entry) => entry.value != null));
  }
}
