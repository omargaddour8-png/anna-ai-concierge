class UserMemory {
  String? name;
  String? vehicle;
  String? city;
  String? phone;

  UserMemory({
    this.name,
    this.vehicle,
    this.city,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'vehicle': vehicle,
        'city': city,
        'phone': phone,
      };

  factory UserMemory.fromJson(Map<String, dynamic> json) {
    return UserMemory(
      name: json['name'],
      vehicle: json['vehicle'],
      city: json['city'],
      phone: json['phone'],
    );
  }
}