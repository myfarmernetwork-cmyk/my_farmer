import 'product.dart';

enum SearchRadius {
  all(null),
  km5(5),
  km10(10),
  km20(20),
  km50(50);

  const SearchRadius(this.maxKm);

  final double? maxKm;

  bool get isAll => this == SearchRadius.all;

  String labelKey() {
    switch (this) {
      case SearchRadius.all:
        return 'search_radius_all';
      case SearchRadius.km5:
      case SearchRadius.km10:
      case SearchRadius.km20:
      case SearchRadius.km50:
        return 'search_radius_km';
    }
  }

  static const selectable = [
    SearchRadius.km5,
    SearchRadius.km10,
    SearchRadius.km20,
    SearchRadius.km50,
    SearchRadius.all,
  ];
}

class RankedProduct {
  final Product product;
  final double? distanceKm;

  const RankedProduct({
    required this.product,
    this.distanceKm,
  });
}
