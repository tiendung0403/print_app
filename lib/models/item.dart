class Item {
  int? id;
  String name;
  String baseUnit; // g, con, cây
  double conversionRate; // Số baseUnit = 1 P (VD: 33g = 1P)
  String customUnitsJson;

  Item({
    this.id,
    required this.name,
    required this.baseUnit,
    required this.conversionRate,
    this.customUnitsJson = '[]',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'base_unit': baseUnit,
      'conversion_rate': conversionRate,
      'custom_units': customUnitsJson,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      baseUnit: map['base_unit'],
      conversionRate: (map['conversion_rate'] as num).toDouble(),
      customUnitsJson: map['custom_units'] ?? '[]',
    );
  }
}
