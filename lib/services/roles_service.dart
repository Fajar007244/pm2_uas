import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  admin,
  customer,
  seller,
  support
}

class RolesService {
  static final _supabase = Supabase.instance.client;

  // Define role constants
  static const Map<UserRole, String> roleNames = {
    UserRole.admin: 'admin',
    UserRole.customer: 'customer',
    UserRole.seller: 'seller',
    UserRole.support: 'support'
  };

  // Define role permissions
  static const Map<UserRole, List<String>> rolePermissions = {
    UserRole.admin: [
      'view_all_users',
      'manage_users',
      'manage_products',
      'view_all_orders',
      'manage_system_settings'
    ],
    UserRole.customer: [
      'view_products',
      'create_order',
      'view_own_orders',
      'manage_own_profile'
    ],
    UserRole.seller: [
      'manage_own_products',
      'view_own_orders',
      'view_products',
      'manage_own_profile'
    ],
    UserRole.support: [
      'view_orders',
      'manage_customer_support',
      'view_user_profiles'
    ]
  };

  // Assign role to a user
  Future<void> assignUserRole({
    required String userId, 
    required UserRole role
  }) async {
    try {
      await _supabase
        .from('users')
        .update({'role': roleNames[role]})
        .eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to assign role: ${e.message}');
    }
  }

  // Get user role
  Future<UserRole?> getUserRole(String userId) async {
    try {
      final response = await _supabase
        .from('users')
        .select('role')
        .eq('id', userId)
        .single();
      
      final roleString = response['role'] as String?;
      
      // Handle null or empty role
      if (roleString == null || roleString.isEmpty) {
        // Assign default role if no role is set
        await assignUserRole(userId: userId, role: UserRole.customer);
        return UserRole.customer;
      }

      // Find matching role, default to customer if not found
      return roleNames.keys.firstWhere(
        (role) => roleNames[role] == roleString, 
        orElse: () {
          // Log unexpected role and assign default
          print('Unexpected role found: $roleString. Defaulting to customer.');
          assignUserRole(userId: userId, role: UserRole.customer);
          return UserRole.customer;
        }
      );
    } on PostgrestException catch (e) {
      // Handle specific Supabase errors
      if (e.code == 'PGRST116') {
        // No user found
        print('No user found with ID: $userId');
        return null;
      }
      throw Exception('Failed to fetch user role: ${e.message}');
    } catch (e) {
      print('Unexpected error fetching user role: $e');
      return null;
    }
  }

  // Bulk update roles for existing users
  Future<void> migrateExistingUsersToRoles() async {
    try {
      // Fetch all users without a role
      final response = await _supabase
        .from('users')
        .select('id')
        .filter('role', 'is', null);

      // Safely handle the response
      final usersWithoutRole = response is List ? response : [];

      // Assign default customer role to users without a role
      for (var user in usersWithoutRole) {
        if (user is Map && user['id'] != null) {
          try {
            await assignUserRole(
              userId: user['id'].toString(), 
              role: UserRole.customer
            );
          } catch (userRoleError) {
            print('Error assigning role to user ${user['id']}: $userRoleError');
          }
        }
      }

      print('Migrated ${usersWithoutRole.length} users to customer role');
    } catch (e) {
      print('Error migrating user roles: $e');
    }
  }

  // Check if user has specific permission
  Future<bool> hasPermission({
    required String userId, 
    required String permission
  }) async {
    try {
      final userRole = await getUserRole(userId);
      if (userRole == null) return false;

      return rolePermissions[userRole]?.contains(permission) ?? false;
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }

  // Validate access to a specific resource
  Future<bool> validateResourceAccess({
    required String userId,
    required String resourceOwnerId,
    required List<String> requiredPermissions
  }) async {
    try {
      final userRole = await getUserRole(userId);
      if (userRole == null) return false;

      // Admin always has access
      if (userRole == UserRole.admin) return true;

      // Check if user is accessing their own resource
      if (userId == resourceOwnerId) return true;

      // Check specific permissions
      return requiredPermissions.any((permission) => 
        rolePermissions[userRole]?.contains(permission) ?? false
      );
    } catch (e) {
      print('Resource access validation error: $e');
      return false;
    }
  }
}
