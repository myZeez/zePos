class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.category,
    required this.costPrice,
    required this.price,
    required this.stock,
    required this.minimumStock,
    required this.isActive,
  });

  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final int costPrice;
  final int price;
  final int stock;
  final int minimumStock;
  final bool isActive;

  factory Product.fromDatabase(Map<String, Object?> values) {
    return Product(
      id: values['id']! as String,
      name: values['name']! as String,
      sku: values['sku']! as String,
      barcode: values['barcode']! as String,
      category: values['category']! as String,
      costPrice: (values['cost_price'] as int?) ?? 0,
      price: values['price']! as int,
      stock: values['stock']! as int,
      minimumStock: (values['minimum_stock'] as int?) ?? 5,
      isActive: values['is_active']! as int == 1,
    );
  }

  Map<String, Object?> toDatabase() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'category': category,
      'cost_price': costPrice,
      'price': price,
      'stock': stock,
      'minimum_stock': minimumStock,
      'is_active': isActive ? 1 : 0,
    };
  }
}
