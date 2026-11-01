import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/subscription_tier.dart';
import '../services/admin_moderation_service.dart';
import '../services/subscription_tier_sync.dart';

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
  final AdminModerationService _moderation = AdminModerationService();



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

  /// Admin — promjena uloge (npr. tester → kupac).
  Future<void> setUserRole({
    required String uid,
    required UserRole newRole,
  }) async {
    final role = AppUser.roleToFirestore(newRole);
    final canonical = AppUser.normalizeRoleAlias(role);

    final doc = await _firestore.collection('users').doc(uid).get();
    final existing = doc.data() ?? {};
    final previousCanonical = AppUser.resolveRoleCanonical(existing);

    final updates = <String, dynamic>{
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (canonical == 'veterinarian' || canonical == 'pharmacy') {
      updates['isPublicProfile'] = false;
      updates['isVerified'] = false;
    } else if (canonical == 'admin') {
      updates['isPublicProfile'] = true;
    } else {
      updates['isPublicProfile'] = true;
    }

    if (canonical == 'buyer') {
      updates['premiumApprovalStatus'] = FieldValue.delete();
      updates['subscriptionTier'] = FieldValue.delete();
      updates['requestedPremiumTier'] = FieldValue.delete();
      updates['promotionalEndsAt'] = FieldValue.delete();
      updates['premiumActive'] = false;
    }

    if (previousCanonical == 'veterinarian' && canonical != 'veterinarian') {
      updates['isVerified'] = false;
    }

    if (previousCanonical == 'professional_farmer' ||
        previousCanonical == 'hobby_farmer') {
      if (canonical == 'buyer' || canonical == 'veterinarian' || canonical == 'pharmacy') {
        updates['isVerified'] = FieldValue.delete();
      }
    }

    updates.addAll(_clearConflictingRoleProfileFields(existing, canonical));

    await _firestore.collection('users').doc(uid).update(updates);
  }

  static bool _hasProfileText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty && text.toLowerCase() != 'null';
  }

  /// Ukloni polja druge uloge da login ne „pogodi“ krivi tip (farmNumber, licence, tier…).
  static Map<String, dynamic> _clearConflictingRoleProfileFields(
    Map<String, dynamic> existing,
    String newCanonical,
  ) {
    final updates = <String, dynamic>{};

    final keepFarm = newCanonical == 'professional_farmer' ||
        newCanonical == 'hobby_farmer';
    if (!keepFarm && _hasProfileText(existing['farmNumber'])) {
      updates['farmNumber'] = FieldValue.delete();
    }

    if (newCanonical != 'veterinarian' &&
        _hasProfileText(existing['veterinaryLicense'])) {
      updates['veterinaryLicense'] = FieldValue.delete();
    }

    if (newCanonical != 'pharmacy' &&
        _hasProfileText(existing['companyRegistrationNumber'])) {
      updates['companyRegistrationNumber'] = FieldValue.delete();
    }

    updates.addAll(_clearMismatchedSubscriptionTier(existing, newCanonical));

    return updates;
  }

  static Set<String> _allowedTiersForRole(String canonical) {
    switch (AppUser.normalizeRoleAlias(canonical)) {
      case 'buyer':
        return {SubscriptionTier.buyerPremium.firestoreValue};
      case 'hobby_farmer':
        return {SubscriptionTier.hobbyFarmerPremium.firestoreValue};
      case 'professional_farmer':
        return {SubscriptionTier.professionalFarmerPremium.firestoreValue};
      case 'veterinarian':
        return {SubscriptionTier.veterinarianLicense.firestoreValue};
      case 'pharmacy':
        return {SubscriptionTier.pharmacyLicense.firestoreValue};
      default:
        return {};
    }
  }

  static Map<String, dynamic> _clearMismatchedSubscriptionTier(
    Map<String, dynamic> existing,
    String newCanonical,
  ) {
    final tier = existing['subscriptionTier']?.toString();
    if (tier == null || tier.isEmpty) {
      return {};
    }

    final canonical = AppUser.normalizeRoleAlias(newCanonical);
    if (canonical == 'buyer' || canonical == 'admin') {
      return {
        'subscriptionTier': FieldValue.delete(),
        'premiumApprovalStatus': FieldValue.delete(),
        'requestedPremiumTier': FieldValue.delete(),
        'premiumActive': false,
      };
    }

    if (!_allowedTiersForRole(canonical).contains(tier)) {
      return {
        'subscriptionTier': FieldValue.delete(),
        'premiumApprovalStatus': FieldValue.delete(),
        'requestedPremiumTier': FieldValue.delete(),
        'premiumActive': false,
      };
    }

    return {};
  }

  /// Admin — Premium bez Google Play (testeri, poklon). Ne otkazuje Play pretplatu.
  Future<void> grantAdminPremium({
    required String uid,
    required SubscriptionTier tier,
    DateTime? expiresAt,
  }) async {
    await _firestore.collection('users').doc(uid).set(
      {
        'subscriptionTier': tier.firestoreValue,
        'premiumApprovalStatus': 'APPROVED',
        'premiumActive': true,
        'premiumGrantedBy': 'admin',
        'premiumGrantedAt': FieldValue.serverTimestamp(),
        'requestedPremiumTier': FieldValue.delete(),
        'weatherAlertsEnabled': true,
        if (expiresAt != null)
          'subscriptionExpiresAt': Timestamp.fromDate(expiresAt.toUtc())
        else
          'subscriptionExpiresAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Ukloni samo admin-dodijeljen Premium (premiumGrantedBy == admin).
  Future<void> revokeAdminPremium({required String uid}) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) {
      throw Exception('Korisnik nije pronađen.');
    }
    if (data['premiumGrantedBy']?.toString() != 'admin') {
      throw Exception(
        'Premium nije dodijeljen iz admin panela (Play pretplata ostaje u Storeu).',
      );
    }

    await doc.reference.update({
      'premiumActive': false,
      'premiumGrantedBy': FieldValue.delete(),
      'premiumGrantedAt': FieldValue.delete(),
      'subscriptionTier': FieldValue.delete(),
      'premiumApprovalStatus': FieldValue.delete(),
      'subscriptionExpiresAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static SubscriptionTier defaultTierForRoleString(String? roleRaw) {
    final role = AppUser.parseRole(AppUser.normalizeRoleAlias(roleRaw));
    return tierForRole(role);
  }

  /// Reset AI skener + NIRS brojače (admin test / podrška).
  Future<void> resetUserUsageQuotas({required String uid}) async {
    await _firestore.collection('users').doc(uid).update({
      'scansThisMonth': 0,
      'introScansUsed': 0,
      'bonusScansBalance': 0,
      'nirsLoadsThisMonth': 0,
      'isTrialUsed': false,
      'hasFreeScans': true,
      'lastScanReset': FieldValue.serverTimestamp(),
      'lastNirsReset': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> findUserByEmail(
    String email,
  ) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final exact = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    if (exact.docs.isNotEmpty) return exact.docs.first;

    final original = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (original.docs.isNotEmpty) return original.docs.first;

    return null;
  }

  Future<void> resetUserUsageQuotasByEmail({required String email}) async {
    final doc = await findUserByEmail(email);
    if (doc == null || !doc.exists) {
      throw Exception('Korisnik s emailom $email nije pronađen.');
    }
    await resetUserUsageQuotas(uid: doc.id);
  }

  /// Admin — ukloni profilnu sliku (Storage + Firestore).
  Future<void> clearUserProfileImage({required String uid}) async {
    await _moderation.clearUserProfileImage(targetUid: uid);
  }

  /// Admin — trajno obriši korisnički račun (Auth + Firestore + objave).
  Future<void> deleteUserAccount({required String uid}) async {
    await _moderation.deleteUserAccount(targetUid: uid);
  }

  /// Admin — ukloni samo sliku s objave u zajednici.
  Future<void> clearCommunityPostImage({required String postId}) async {
    final ref = await _findCommunityPostRef(postId);
    if (ref == null) {
      throw Exception('Objava nije pronađena.');
    }

    final data = (await ref.get()).data();
    if (data == null) {
      throw Exception('Objava nije pronađena.');
    }

    await _deleteStorageUrl(data['imageUrl']?.toString());

    await ref.update({
      'imageUrl': FieldValue.delete(),
      'imageAspectRatio': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin — obriši cijelu objavu u zajednici (bez blokade autora).
  Future<void> deleteCommunityPost({required String postId}) async {
    final ref = await _findCommunityPostRef(postId);
    if (ref == null) return;

    final data = (await ref.get()).data();
    await _deleteStorageUrl(data?['imageUrl']?.toString());
    await ref.delete();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchCommunityPostsForAdmin({String? userId, int limit = 200}) {
    if (userId != null && userId.isNotEmpty) {
      final controller =
          StreamController<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.broadcast();
      QuerySnapshot<Map<String, dynamic>>? byAuthor;
      QuerySnapshot<Map<String, dynamic>>? byUser;

      void emitMerged() {
        final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snapshot in [byAuthor, byUser]) {
          if (snapshot == null) continue;
          for (final doc in snapshot.docs) {
            merged[doc.id] = doc;
          }
        }
        final docs = merged.values.toList()..sort((a, b) {
          final aDate = a.data()['timestamp'];
          final bDate = b.data()['timestamp'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });
        if (!controller.isClosed) controller.add(docs);
      }

      final subscriptions = [
        _firestore
            .collection('community_posts')
            .where('authorId', isEqualTo: userId)
            .snapshots()
            .listen((snapshot) {
          byAuthor = snapshot;
          emitMerged();
        }),
        _firestore
            .collection('community_posts')
            .where('userId', isEqualTo: userId)
            .snapshots()
            .listen((snapshot) {
          byUser = snapshot;
          emitMerged();
        }),
      ];

      controller.onCancel = () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
      };

      return controller.stream;
    }

    return _firestore
        .collection('community_posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(_sortPostDocsNewest);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchProductsForAdmin({
    String? sellerId,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('products');
    if (sellerId != null && sellerId.isNotEmpty) {
      query = query.where('sellerId', isEqualTo: sellerId);
    } else {
      query = query.orderBy('createdAt', descending: true).limit(limit);
    }

    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aDate = a.data()['createdAt'];
          final bDate = b.data()['createdAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });
      return docs;
    });
  }

  /// Admin — ukloni sliku proizvoda s tržnice.
  Future<void> clearProductImage({required String productId}) async {
    final ref = _firestore.collection('products').doc(productId);
    final data = (await ref.get()).data();
    if (data == null) {
      throw Exception('Proizvod nije pronađen.');
    }

    await _deleteStorageUrl(data['imageUrl']?.toString());
    await ref.update({
      'imageUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin — obriši proizvod s tržnice.
  Future<void> deleteProduct({required String productId}) async {
    final ref = _firestore.collection('products').doc(productId);
    final data = (await ref.get()).data();
    if (data != null) {
      await _deleteStorageUrl(data['imageUrl']?.toString());
    }
    await ref.delete();
  }

  Future<int> countProductsForSeller(String sellerId) async {
    final id = sellerId.trim();
    if (id.isEmpty) return 0;
    final snap = await _firestore
        .collection('products')
        .where('sellerId', isEqualTo: id)
        .get();
    return snap.docs.length;
  }

  /// Admin — ukloni sve oglase prodavača (npr. pri prebacivanju na kupca).
  Future<int> deleteAllProductsForSeller({required String sellerId}) async {
    final id = sellerId.trim();
    if (id.isEmpty) return 0;
    final snap = await _firestore
        .collection('products')
        .where('sellerId', isEqualTo: id)
        .get();
    var deleted = 0;
    for (final doc in snap.docs) {
      await deleteProduct(productId: doc.id);
      deleted++;
    }
    return deleted;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortPostDocsNewest(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aDate = a.data()['timestamp'];
        final bDate = b.data()['timestamp'];
        if (aDate is Timestamp && bDate is Timestamp) {
          return bDate.compareTo(aDate);
        }
        return 0;
      });
    return docs;
  }

  static Future<void> _deleteStorageUrl(String? imageUrl) async {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findCommunityPostRef(
    String postId,
  ) async {
    final primary = _firestore.collection('community_posts').doc(postId);
    if ((await primary.get()).exists) return primary;

    final legacy = _firestore.collection('posts').doc(postId);
    if ((await legacy.get()).exists) return legacy;

    return null;
  }

  Future<void> approveUserByEmail({required String email}) async {
    final doc = await findUserByEmail(email);
    if (doc == null || !doc.exists) {
      throw Exception('Korisnik s emailom $email nije pronađen.');
    }
    await approveUser(doc.id);
  }

  static int _quotaInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String usageQuotaSummary(Map<String, dynamic> data) {
    final scans = _quotaInt(data, 'scansThisMonth');
    final intro = _quotaInt(data, 'introScansUsed');
    final bonus = _quotaInt(data, 'bonusScansBalance');
    final nirs = _quotaInt(data, 'nirsLoadsThisMonth');
    final trialUsed = data['isTrialUsed'] == true ? 'da' : 'ne';
    final freeScans = data['hasFreeScans'] != false ? 'da' : 'ne';
    return 'AI skenovi (mj): $scans · Uvodni: $intro · Bonus: $bonus · NIRS (mj): $nirs · Trial: $trialUsed · Free: $freeScans';
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


