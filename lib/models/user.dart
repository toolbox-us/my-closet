import 'json_utils.dart';

/// The signed-in account.
///
/// Authentication is mocked throughout (`MockAuthRepository`) - the course
/// requirements do not call for a real identity provider, and a mock keeps
/// the prototype runnable offline. The shape is deliberately the shape a real
/// provider would return, so swapping it later touches one repository.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.genderPreference = '',
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;

  /// Clothing preference collected at signup ("Menswear" / "Womenswear" /
  /// "Both"). Named for what it drives - which garments are suggested - not
  /// as a gender identity field.
  final String genderPreference;

  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: J.str(json['id']),
        name: J.str(json['name']),
        email: J.str(json['email']),
        phone: J.str(json['phone']),
        genderPreference: J.str(json['genderPreference']),
        createdAt: J.date(json['createdAt']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'genderPreference': genderPreference,
        'createdAt': J.dateToJson(createdAt),
      };

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? genderPreference,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        genderPreference: genderPreference ?? this.genderPreference,
        createdAt: createdAt,
      );
}
