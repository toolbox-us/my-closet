import 'json_utils.dart';

/// Style preferences, lifestyle and sizes.
///
/// This is not decoration: `preferredStyles`, `favoriteColors` and
/// `avoidedColors` are direct inputs to the recommendation engine's Style
/// Preference and Colour Compatibility scores. Onboarding exists to populate
/// it.
class UserProfile {
  const UserProfile({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.genderPreference = '',
    this.preferredStyles = const <String>[],
    this.favoriteColors = const <String>[],
    this.avoidedColors = const <String>[],
    this.preferredBrands = const <String>[],
    this.hobbies = const <String>[],
    this.sizes = const <String, String>{},
    this.onboardingComplete = false,
  });

  final String name;
  final String email;
  final String phone;
  final String location;
  final String genderPreference;

  final List<String> preferredStyles;
  final List<String> favoriteColors;
  final List<String> avoidedColors;
  final List<String> preferredBrands;
  final List<String> hobbies;

  /// Size kind -> value, e.g. `{'Shirt': 'M', 'Shoes': '10'}`.
  final Map<String, String> sizes;

  final bool onboardingComplete;

  static const UserProfile empty = UserProfile();

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: J.str(json['name']),
        email: J.str(json['email']),
        phone: J.str(json['phone']),
        location: J.str(json['location']),
        genderPreference: J.str(json['genderPreference']),
        preferredStyles: J.strList(json['preferredStyles']),
        favoriteColors: J.strList(json['favoriteColors']),
        avoidedColors: J.strList(json['avoidedColors']),
        preferredBrands: J.strList(json['preferredBrands']),
        hobbies: J.strList(json['hobbies']),
        sizes: J.strMap(json['sizes']),
        onboardingComplete: J.boolean(json['onboardingComplete']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'genderPreference': genderPreference,
        'preferredStyles': preferredStyles,
        'favoriteColors': favoriteColors,
        'avoidedColors': avoidedColors,
        'preferredBrands': preferredBrands,
        'hobbies': hobbies,
        'sizes': sizes,
        'onboardingComplete': onboardingComplete,
      };

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    String? genderPreference,
    List<String>? preferredStyles,
    List<String>? favoriteColors,
    List<String>? avoidedColors,
    List<String>? preferredBrands,
    List<String>? hobbies,
    Map<String, String>? sizes,
    bool? onboardingComplete,
  }) =>
      UserProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        genderPreference: genderPreference ?? this.genderPreference,
        preferredStyles: preferredStyles ?? this.preferredStyles,
        favoriteColors: favoriteColors ?? this.favoriteColors,
        avoidedColors: avoidedColors ?? this.avoidedColors,
        preferredBrands: preferredBrands ?? this.preferredBrands,
        hobbies: hobbies ?? this.hobbies,
        sizes: sizes ?? this.sizes,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );
}
