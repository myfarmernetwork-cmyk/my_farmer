import 'package:cloud_firestore/cloud_firestore.dart';



import '../models/app_user.dart';

import '../models/subscription_tier.dart';

enum AdminUserListFilter {
  all,
  buyer,
  hobbyFarmer,
  professionalFarmer,
  veterinarian,
  pharmacy,
  admin,
  pendingPremium,
}

class AdminRepository {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  static bool isVerificationRole(String? role) {

    final canonical = AppUser.normalizeRoleAlias(role);

    return canonical == 'veterinarian' || canonical == 'pharmacy';

  }



  /// Premium zahtjevi na čekanju — veterinar 9,99 € / tvrtka 19,99 €.

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>

      pendingVerifications() {

    return _firestore.collection('users').snapshots().map(

          (snapshot) => snapshot.docs.where((doc) {

            final data = doc.data();

            if (!isVerificationRole(data['role']?.toString())) return false;



            final premiumStatus = data['premiumApprovalStatus']

                    ?.toString()

                    .trim()

                    .toUpperCase() ??

                '';

            return premiumStatus == 'PENDING';

          }).toList(),

        );

  }



  Stream<QuerySnapshot<Map<String, dynamic>>> allUsers() {

    return _firestore.collection('users').snapshots();

  }



  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> buyers() {
    return usersForFilter(AdminUserListFilter.buyer);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> usersForFilter(
    AdminUserListFilter filter,
  ) {
    if (filter == AdminUserListFilter.pendingPremium) {
      return pendingVerifications();
    }

    return allUsers().map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final role = AppUser.normalizeRoleAlias(data['role']?.toString());
        switch (filter) {
          case AdminUserListFilter.all:
            return true;
          case AdminUserListFilter.buyer:
            return role == 'buyer' || role.isEmpty;
          case AdminUserListFilter.hobbyFarmer:
            return role == 'hobby_farmer';
          case AdminUserListFilter.professionalFarmer:
            return role == 'professional_farmer';
          case AdminUserListFilter.veterinarian:
            return role == 'veterinarian';
          case AdminUserListFilter.pharmacy:
            return role == 'pharmacy';
          case AdminUserListFilter.admin:
            return role == 'admin';
          case AdminUserListFilter.pendingPremium:
            return false;
        }
      }).toList()
        ..sort((a, b) {
          final aDate = a.data()['createdAt'];
          final bDate = b.data()['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });
    });
  }

  static String roleLabel(String? role) {
    final canonical = AppUser.normalizeRoleAlias(role);
    switch (canonical) {
      case 'buyer':
        return 'Kupac';
      case 'hobby_farmer':
        return 'Hobi Farmer';
      case 'professional_farmer':
        return 'Pro Farmer';
      case 'veterinarian':
        return 'Veterinar';
      case 'pharmacy':
        return 'Tvrtka';
      case 'admin':
        return 'Admin';
      default:
        return canonical.isEmpty ? 'Kupac' : canonical;
    }
  }



  Future<void> approveUser(String uid) async {

    final doc = await _firestore.collection('users').doc(uid).get();

    final data = doc.data() ?? {};

    final role =

        AppUser.normalizeRoleAlias(data['role']?.toString());

    final isVet = role == 'veterinarian';

    final requestedTier =

        data['requestedPremiumTier']?.toString() ??

            (isVet

                ? SubscriptionTier.veterinarianLicense.firestoreValue

                : SubscriptionTier.pharmacyLicense.firestoreValue);



    await _firestore.collection('users').doc(uid).update({

      'status': 'ACTIVE',

      'isVerified': true,

      'isPublicProfile': !isVet,

      'premiumApprovalStatus': 'APPROVED',

      'subscriptionTier': requestedTier,

      'premiumApprovedAt': FieldValue.serverTimestamp(),

      'verifiedAt': FieldValue.serverTimestamp(),

      'promotionalEndsAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 90)),
      ),

      'role': role,

    });

  }



  Future<void> rejectUser(String uid) async {

    await _firestore.collection('users').doc(uid).update({

      'premiumApprovalStatus': 'REJECTED',

      'requestedPremiumTier': FieldValue.delete(),

    });

  }

  Future<void> setUserActive({
    required String uid,
    required bool isActive,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
      'status': isActive ? 'ACTIVE' : 'BLOCKED',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }



  static String verificationRoleLabel(String? role) {

    final canonical = AppUser.normalizeRoleAlias(role).toUpperCase();

    switch (canonical) {

      case 'VETERINARIAN':

        return 'VETERINAR';

      case 'PHARMACY':

        return 'FIRMA';

      default:

        return canonical.isEmpty ? '—' : canonical;

    }

  }

}


