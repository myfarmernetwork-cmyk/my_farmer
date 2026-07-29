enum ForumCategory {
  greenhouse,
  fruitGrowing,
  fieldCrops,
  livestock,
  mechanization,
}

extension ForumCategoryX on ForumCategory {
  String get firestoreValue {
    switch (this) {
      case ForumCategory.greenhouse:
        return 'greenhouse';
      case ForumCategory.fruitGrowing:
        return 'fruit_growing';
      case ForumCategory.fieldCrops:
        return 'field_crops';
      case ForumCategory.livestock:
        return 'livestock';
      case ForumCategory.mechanization:
        return 'mechanization';
    }
  }

  String get labelKey {
    switch (this) {
      case ForumCategory.greenhouse:
        return 'forum_cat_greenhouse';
      case ForumCategory.fruitGrowing:
        return 'forum_cat_fruit';
      case ForumCategory.fieldCrops:
        return 'forum_cat_vegetables';
      case ForumCategory.livestock:
        return 'forum_cat_livestock';
      case ForumCategory.mechanization:
        return 'forum_cat_machinery';
    }
  }

  static ForumCategory fromFirestore(String? value) {
    return ForumCategory.values.firstWhere(
      (category) => category.firestoreValue == value,
      orElse: () => ForumCategory.fieldCrops,
    );
  }
}
