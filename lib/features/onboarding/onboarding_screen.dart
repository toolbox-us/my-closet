import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/vocab.dart';
import '../../core/widgets/common.dart';
import '../../models/user_profile.dart';
import '../../providers/providers.dart';

/// Five-step onboarding.
///
/// Everything collected here is a direct input to the recommendation engine -
/// `preferredStyles` drives the Style Preference score, `favoriteColors` and
/// `avoidedColors` adjust Colour Compatibility. Steps 2 to 5 are skippable;
/// the engine falls back to neutral scoring for anything left blank.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final Map<String, TextEditingController> _sizeControllers =
      <String, TextEditingController>{
    for (final String kind in Vocab.sizeKinds) kind: TextEditingController(),
  };

  int _step = 0;
  bool _prefilled = false;
  bool _saving = false;

  String _clothingPreference = 'Menswear';
  List<String> _styles = <String>[];
  List<String> _favoriteColors = <String>[];
  List<String> _avoidedColors = <String>[];
  List<String> _hobbies = <String>[];

  static const int _stepCount = 5;

  static const List<String> _preferences = <String>[
    'Menswear',
    'Womenswear',
    'Both',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _location.dispose();
    for (final TextEditingController c in _sizeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pulls across whatever signup already collected, so step 1 is not a
  /// second round of typing the same name.
  void _prefillOnce(UserProfile profile) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = profile.name;
    _location.text = profile.location;
    if (profile.genderPreference.isNotEmpty &&
        _preferences.contains(profile.genderPreference)) {
      _clothingPreference = profile.genderPreference;
    }
    if (profile.preferredStyles.isNotEmpty) {
      _styles = List<String>.from(profile.preferredStyles);
    }
    if (profile.favoriteColors.isNotEmpty) {
      _favoriteColors = List<String>.from(profile.favoriteColors);
    }
    if (profile.avoidedColors.isNotEmpty) {
      _avoidedColors = List<String>.from(profile.avoidedColors);
    }
    if (profile.hobbies.isNotEmpty) {
      _hobbies = List<String>.from(profile.hobbies);
    }
    profile.sizes.forEach((String kind, String value) {
      _sizeControllers[kind]?.text = value;
    });
  }

  bool get _canAdvance {
    if (_step == 0) return _name.text.trim().length >= 2;
    return true;
  }

  void _goTo(int step) {
    final int clamped = step.clamp(0, _stepCount - 1);
    setState(() => _step = clamped);
    _pageController.animateToPage(
      clamped,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish(UserProfile existing) async {
    if (_name.text.trim().length < 2) {
      _goTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name to continue.')),
      );
      return;
    }

    setState(() => _saving = true);

    final Map<String, String> sizes = <String, String>{};
    _sizeControllers.forEach((String kind, TextEditingController c) {
      final String value = c.text.trim();
      if (value.isNotEmpty) sizes[kind] = value;
    });

    await ref.read(profileControllerProvider.notifier).completeOnboarding(
          existing.copyWith(
            name: _name.text.trim(),
            location: _location.text.trim(),
            genderPreference: _clothingPreference,
            preferredStyles: _styles,
            favoriteColors: _favoriteColors,
            avoidedColors: _avoidedColors,
            hobbies: _hobbies,
            sizes: sizes,
          ),
        );

    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<UserProfile> profileAsync =
        ref.watch(profileControllerProvider);

    final UserProfile profile = profileAsync.valueOrNull ?? UserProfile.empty;
    if (profileAsync.hasValue) _prefillOnce(profile);

    final bool isLastStep = _step == _stepCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_step + 1} of $_stepCount'),
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goTo(_step - 1),
              ),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _stepCount,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          _personalStep(),
          _styleStep(),
          _colorStep(),
          _lifestyleStep(),
          _sizeStep(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: <Widget>[
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _goTo(_step - 1),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          if (isLastStep) {
                            _finish(profile);
                          } else if (_canAdvance) {
                            _goTo(_step + 1);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your name.'),
                              ),
                            );
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(isLastStep ? 'Finish' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepScaffold({
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool skippable = true,
  }) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (skippable) ...<Widget>[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _goTo(_step + 1),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Skip this step'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }

  Widget _personalStep() => _stepScaffold(
        title: 'About you',
        subtitle: 'Only your name is required.',
        skippable: false,
        children: <Widget>[
          LabeledField(
            label: 'Name',
            child: TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your name'),
              onChanged: (_) => setState(() {}),
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
          LabeledField(
            label: 'Location',
            optional: true,
            child: TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'City, state',
                helperText: 'Used only to label mock weather.',
              ),
            ),
          ),
        ],
      );

  Widget _styleStep() => _stepScaffold(
        title: 'Your style',
        subtitle: 'Pick as many as fit. These weight every recommendation.',
        children: <Widget>[
          ChipMultiSelect(
            options: Vocab.styles,
            selected: _styles,
            onChanged: (List<String> next) => setState(() => _styles = next),
          ),
        ],
      );

  Widget _colorStep() => _stepScaffold(
        title: 'Colors',
        subtitle: 'What you reach for, and what you would rather not wear.',
        children: <Widget>[
          const SectionHeader(title: 'Colors you like'),
          ChipMultiSelect(
            options: Vocab.colors,
            selected: _favoriteColors,
            onChanged: (List<String> next) {
              setState(() {
                _favoriteColors = next;
                // A colour cannot be both liked and avoided.
                _avoidedColors = _avoidedColors
                    .where((String c) => !next.contains(c))
                    .toList();
              });
            },
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Colors to avoid'),
          ChipMultiSelect(
            options: Vocab.colors,
            selected: _avoidedColors,
            onChanged: (List<String> next) {
              setState(() {
                _avoidedColors = next;
                _favoriteColors = _favoriteColors
                    .where((String c) => !next.contains(c))
                    .toList();
              });
            },
          ),
        ],
      );

  Widget _lifestyleStep() => _stepScaffold(
        title: 'Your week',
        subtitle: 'Where your clothes actually need to work.',
        children: <Widget>[
          ChipMultiSelect(
            options: Vocab.hobbies,
            selected: _hobbies,
            onChanged: (List<String> next) => setState(() => _hobbies = next),
          ),
        ],
      );

  Widget _sizeStep() => _stepScaffold(
        title: 'Sizes',
        subtitle: 'Handy when you add items later. Fill in what you know.',
        children: <Widget>[
          for (final String kind in Vocab.sizeKinds)
            LabeledField(
              label: kind,
              optional: true,
              child: TextFormField(
                controller: _sizeControllers[kind],
                decoration: InputDecoration(
                  hintText: kind == 'Shoes' ? 'e.g. 10' : 'e.g. M',
                ),
              ),
            ),
        ],
      );
}
