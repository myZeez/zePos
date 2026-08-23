class StoreProfile {
  const StoreProfile({
    required this.storeName,
    required this.ownerName,
    required this.address,
    required this.phone,
  });

  final String storeName;
  final String ownerName;
  final String address;
  final String phone;

  factory StoreProfile.fromDatabase(Map<String, Object?> values) {
    return StoreProfile(
      storeName: values['store_name']! as String,
      ownerName: values['owner_name']! as String,
      address: values['address']! as String,
      phone: values['phone']! as String,
    );
  }

  Map<String, Object?> toDatabase() => {
    'store_name': storeName,
    'owner_name': ownerName,
    'address': address,
    'phone': phone,
  };
}
