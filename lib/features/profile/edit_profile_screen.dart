import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/vocab.dart';
import '../../core/widgets/common.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';

/// Edit every profile field.
///
/// Saving writes through the profile repository, so the change is persisted
/// and the recommendation engine picks it up on the next request - no restart
/// and no cache to invalidate.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _brands = TextEditingController();
  final Map<String, TextEditingController> _sizes =
      <String, TextEditingController>{
    for (final String kind in Vocab.sizeKinds) kind: TextEditingController(),
  };

  String _clothingPreference = 'Menswear';
  List<String> _styles = <String>[];
  List<String> _favoriteColors = <String>[];
  List<String> _avoidedColors = <String>[];
  List<String> _hobbies = <String>[];

  bool _prefilled = false;
  bool _saving = false;

  static const List<String> _preferences = <String>[
    'Menswear',
    'Womenswear',
    'Both',
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _brands.dispose();
    for (final TextEditingController c in _sizes.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefillOnce(UserProfile profile) {
    if (_prefilled) return;
    _prefilled = true;

    _name.text = profile.name;
    _email.text = profile.email;
    _phone.text = profile.phone;
    _location.text = profile.location;
    _brands.text = profile.preferredBrands.join(', ');

    if (_preferences.contains(profile.genderPreference)) {
      _clothingPreference = profile.genderPreference;
    }
    _styles = List<String>.from(profile.preferredStyles);
    _favoriteColors = List<String>.from(profile.favoriteColors);
    _avoidedColors = List<String>.from(profile.avoidedColors);
    _hobbies = List<String>.from(profile.hobbies);
    profile.sizes.forEach((String kind, String value) {
      _sizes[kind]?.text = value;
    });
  }

  Future<void> _save(UserProfile existing) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final Map<String, String> sizes = <String, String>{};
    _sizes.forEach((String kind, TextEditingController c) {
      final String value = c.text.trim();
      if (value.isNotEmpty) sizes[kind] = value;
    });

    final List<String> brands = _brands.text
        .split(',')
        .map((String b) => b.trim())
        .where((String b) => b.isNotEmpty)
        .toList();

    await ref.read(profileControllerProvider.notifier).save(
          existing.copyWith(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            location: _location.text.trim(),
            genderPreference: _clothingPreference,
            preferredStyles: _styles,
            favoriteColors: _favoriteColors,
            avoidedColors: _avoidedColors,
            preferredBrands: brands,
            hobbies: _hobbies,
            sizes: sizes,
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile> profileAsync =
        ref.watch(profileControllerProvider);
    final UserProfile profile = profileAsync.valueOrNull ?? UserProfile.empty;
    if (profileAsync.hasValue) _prefillOnce(profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: <Widget>[
            const SectionHeader(title: 'Personal information'),

            LabeledField(
              label: 'Name',
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Name is required'
                        : null,
              ),
            ),
            LabeledField(
              label: 'Email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
            ),
            LabeledField(
              label: 'Phone',
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
            ),
            LabeledField(
              label: 'Location',
              optional: true,
              child: TextFormField(
                controller: _location,
                textCapitalization: TextCapitalization.words,
              ),
            ),
            LabeledField(
              label: 'Clothing preference',
              child: ChipSingleSelect(
                options: _preferences,
                selected: _clothingPreference,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() => _clothingPreference = value);
                  }
                },
              ),
            ),

            const SizedBox(height: 12),
            const SectionHeader(
              title: 'Style preferences',
              subtitle: 'Changes take effect on the next recommendation.',
            ),

            LabeledField(
              label: 'Preferred styles',
              child: ChipMultiSelect(
                options: Vocab.styles,
                selected: _styles,
                onChanged: (List<String> next) =>
                    setState(() => _styles = next),
              ),
            ),
            LabeledField(
              label: 'Favorite colors',
              child: ChipMultiSelect(
                options: Vocab.colors,
                selected: _favoriteColors,
                onChanged: (List<String> next) => setState(() {
                  _favoriteColors = next;
                  _avoidedColors = _avoidedColors
                      .where((String c) => !next.contains(c))
                      .toList();
                }),
              ),
            ),
            LabeledField(
              label: 'Colors to avoid',
              child: ChipMultiSelect(
                options: Vocab.colors,
                selected: _avoidedColors,
                onChanged: (List<String> next) => setState(() {
                  _avoidedColors = next;
                  _favoriteColors = _favoriteColors
                      .where((String c) => !next.contains(c))
                      .toList();
                }),
              ),
            ),
            LabeledField(
              label: 'Preferred brands',
              optional: true,
              child: TextFormField(
                controller: _brands,
                decoration: const InputDecoration(
                  hintText: 'comma separated',
                ),
              ),
            ),

            const SizedBox(height: 12),
            const SectionHeader(title: 'Lifestyle'),
            LabeledField(
              label: 'Activities',
              child: ChipMultiSelect(
                options: Vocab.hobbies,
                selected: _hobbies,
                onChanged: (List<String> next) =>
                    setState(() => _hobbies = next),
              ),
            ),

            const SizedBox(height: 12),
            const SectionHeader(title: 'Sizes'),
            for (final String kind in Vocab.sizeKinds)
              LabeledField(
                label: kind,
                optional: true,
                child: TextFormField(controller: _sizes[kind]),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : () => _save(profile),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save changes'),
          ),
        ),
      ),
    );
  }
}
