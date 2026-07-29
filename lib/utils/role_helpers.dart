bool isFarmerRole(String? role) {
  return role == 'hobby_farmer' ||
      role == 'professional_farmer' ||
      role == 'farmer';
}

bool isSellerNavRole(String? role) {
  final canonical = role?.trim().toLowerCase() ?? '';
  return canonical == 'hobby_farmer' ||
      canonical == 'hobbyist_farmer' ||
      canonical == 'professional_farmer' ||
      canonical == 'pro_farmer' ||
      canonical == 'farmer' ||
      canonical == 'services' ||
      canonical == 'pharmacy' ||
      canonical == 'company' ||
      canonical == 'veterinarian';
}

bool isProfessionalFarmer(String? role) {
  return role == 'professional_farmer' ||
      role == 'farmer' ||
      role == 'services';
}
