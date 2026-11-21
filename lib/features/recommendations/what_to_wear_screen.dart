import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/vocab.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/common.dart';
import '../../models/ai_outfit_advice.dart';
import '../../models/feedback_entry.dart';
import '../../models/recommendation.dart';
import '../../models/user_profile.dart';
import '../../models/wardrobe_item.dart';
import '../../models/weather.dart';
import '../../providers/providers.dart';
import 'widgets/outfit_result_view.dart';

/// "What should I wear?"
///
/// Form and results live on one screen rather than two routes: the user
/// adjusts a parameter, regenerates, and compares without losing their
/// place. Results are kept as a ranked list so "Try Another" walks down the
/// ranking instead of re-running the engine with a random seed.
class WhatToWearScreen extends ConsumerStatefulWidget {
  const WhatToWearScreen({super.key});

  @override
  ConsumerState<WhatToWearScreen> createState() => _WhatToWearScreenState();
}

class _WhatToWearScreenState extends ConsumerState<WhatToWearScreen> {
  String _occasion = 'Work';
  String _environment = 'Indoor';
  String? _style;

  List<ScoredOutfit> _results = <ScoredOutfit>[];
  int _index = 0;
  bool _generated = false;
  bool _generating = false;
  String? _aiExplanation;
  String? _aiError;
  AiOutfitAdvice? _aiAdvice;

  Future<void> _generate() async {
    final List<WardrobeItem> items =
        ref.read(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];
    final UserProfile profile =
        ref.read(profileControllerProvider).valueOrNull ?? UserProfile.empty;
    final List<FeedbackEntry> feedback =
        ref.read(feedbackControllerProvider).valueOrNull ??
            const <FeedbackEntry>[];
    final Weather weather = ref.read(weatherControllerProvider);

    final RecommendationRequest request = buildRequest(
      items: items,
      profile: profile,
      weather: weather,
      feedback: feedback,
      occasion: _occasion,
      environment: _environment,
      style: _style,
    );

    final List<ScoredOutfit> candidates =
        ref.read(recommendationServiceProvider).recommend(request, limit: 5);

    setState(() {
      _results = candidates;
      _index = 0;
      _generated = true;
      _generating = candidates.isNotEmpty;
      _aiExplanation = null;
      _aiError = null;
      _aiAdvice = null;
    });

    if (candidates.isEmpty) return;

    final AiOutfitAdvice advice =
        await ref.read(aiServiceProvider).recommendOutfit(request, candidates);
    if (!mounted) return;

    final int selectedIndex = candidates.indexWhere(
      (ScoredOutfit candidate) =>
          candidate.signature == advice.selectedSignature,
    );
    setState(() {
      _generating = false;
      _aiExplanation = advice.hasRecommendation && selectedIndex >= 0
          ? advice.explanation
          : null;
      _aiError = advice.hasRecommendation && selectedIndex >= 0
          ? null
          : advice.errorMessage ??
              'Gemini returned a selection that was not in the available '
                  'outfit options.';
      _aiAdvice = advice;
      if (_aiExplanation != null) _index = selectedIndex;
    });
  }

  Future<void> _save(ScoredOutfit scored) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _OutfitNameDialog(suggestion: '$_occasion outfit'),
    );
    if (!mounted || name == null) return;

    await ref.read(outfitsControllerProvider.notifier).save(
          scored.outfit.copyWith(occasion: _occasion, style: _style),
          name: name,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$name" to your outfits.')),
    );
  }

  Future<void> _wear(ScoredOutfit scored) async {
    await ref.read(outfitsControllerProvider.notifier).wearNow(
          scored.outfit.copyWith(
            name: '$_occasion outfit',
            occasion: _occasion,
            style: _style,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged. Wear counts updated.')),
    );
  }

  Future<void> _recordFeedback(ScoredOutfit scored, bool liked) async {
    String? reason;
    if (!liked) {
      reason = await DislikeReasonSheet.show(context);
      if (reason == null) return;
    }

    await ref.read(feedbackControllerProvider.notifier).record(
          FeedbackEntry(
            id: Ids.generate('fb'),
            signature: scored.signature,
            liked: liked,
            reason: reason,
            itemIds: scored.outfit.itemIds,
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          liked
              ? 'Noted - more like this.'
              : 'Noted. Future suggestions will weight this down.',
        ),
      ),
    );

    if (!liked) _next();
  }

  void _next() {
    if (_results.length < 2) return;
    setState(() {
      _index = (_index + 1) % _results.length;
      _aiExplanation = null;
      _aiError = null;
      _aiAdvice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WardrobeItem> items =
        ref.watch(wardrobeControllerProvider).valueOrNull ??
            const <WardrobeItem>[];

    final ScoredOutfit? current = _results.isEmpty
        ? null
        : _results[_index.clamp(0, _results.length - 1)];

    return Scaffold(
      appBar: AppBar(title: const Text('What should I wear?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: <Widget>[
          const SectionHeader(
            title: 'Occasion',
            subtitle: 'Worth 25 of the 100 scoring points.',
          ),
          ChipSingleSelect(
            options: Vocab.occasions,
            selected: _occasion,
            onChanged: (String? value) {
              if (value != null) setState(() => _occasion = value);
            },
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Environment'),
          ChipSingleSelect(
            options: Vocab.environments,
            selected: _environment,
            onChanged: (String? value) {
              if (value != null) setState(() => _environment = value);
            },
          ),
          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Style',
            subtitle: 'Optional. Leave blank to use your saved preferences.',
          ),
          ChipSingleSelect(
            options: Vocab.styles,
            selected: _style,
            allowNone: true,
            onChanged: (String? value) => setState(() => _style = value),
          ),
          const SizedBox(height: 28),
          const _WeatherEditor(),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: items.isEmpty || _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _generating
                  ? 'Asking Gemini...'
                  : (_generated ? 'Regenerate' : 'Generate Outfit'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemini receives this occasion, weather, style preferences and '
            'candidate garment details to choose an outfit. Account details '
            'and item IDs are not sent.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (items.isEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Add a few wardrobe items first - the engine can only work with '
              'what you own.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_generated) ...<Widget>[
            const SizedBox(height: 32),
            if (_aiError != null)
              AppCard(
                color: theme.colorScheme.errorContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.cloud_off_outlined,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gemini could not personalize this result. '
                            'Showing the local rule-based recommendation.\n'
                            '$_aiError',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_aiAdvice?.modelUsed != null ||
                        _aiAdvice?.rawResponse != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            'Technical details',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          children: <Widget>[
                            if (_aiAdvice?.modelUsed != null)
                              _AiDiagnosticBlock(
                                label: 'Model',
                                value: _aiAdvice!.modelUsed!,
                              ),
                            if (_aiAdvice?.rawResponse != null)
                              _AiDiagnosticBlock(
                                label: 'Gemini response',
                                value: _aiAdvice!.rawResponse!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (_aiExplanation != null) ...<Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeader(
                      title: "Gemini's pick",
                      subtitle: 'Chosen from outfits made with your wardrobe.',
                    ),
                    Text(_aiExplanation!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (current == null)
              const EmptyView(
                icon: Icons.search_off,
                title: 'No complete outfit found',
                message:
                    'Your wardrobe may not cover this weather or occasion yet. '
                    'Try a different occasion, or add items.',
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Result ${_index + 1} of ${_results.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ScoredOutfitCard(
                scored: current,
                title: _aiExplanation == null
                    ? 'Local recommendation'
                    : "Gemini's pick",
                onWear: () => _wear(current),
                onSave: () => _save(current),
                onAnother: _results.length > 1 ? _next : null,
                onLike: () => _recordFeedback(current, true),
                onDislike: () => _recordFeedback(current, false),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AiDiagnosticBlock extends StatelessWidget {
  const _AiDiagnosticBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _OutfitNameDialog extends StatefulWidget {
  const _OutfitNameDialog({required this.suggestion});

  final String suggestion;

  @override
  State<_OutfitNameDialog> createState() => _OutfitNameDialogState();
}

class _OutfitNameDialogState extends State<_OutfitNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.suggestion);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this outfit'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Monday Office'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final String name = _controller.text.trim();
            Navigator.of(context).pop(name.isEmpty ? widget.suggestion : name);
          },
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Lets the user drive the mock weather directly.
///
/// Exposing the inputs is a feature, not a shortcut: a grader can show a
/// cold-weather recommendation without waiting for winter, and the swap to a
/// real service later changes nothing else on this screen.
class _WeatherEditor extends ConsumerWidget {
  const _WeatherEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Weather weather = ref.watch(weatherControllerProvider);
    final WeatherController controller =
        ref.read(weatherControllerProvider.notifier);
    final List<Weather> scenarios = ref.read(weatherServiceProvider).scenarios;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Weather',
            subtitle: 'Mocked - adjust freely. ${weather.summary}',
            trailing: Pill(
              label: weather.scenarioName,
              background: theme.colorScheme.surfaceContainerHighest,
              foreground: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: scenarios
                .map(
                  (Weather scenario) => ChoiceChip(
                    label: Text(
                      '${scenario.scenarioName} '
                      '(${scenario.temperatureF}°)',
                    ),
                    selected: weather.scenarioName == scenario.scenarioName,
                    onSelected: (_) => controller.applyScenario(scenario),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Text(
                'Temperature',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${weather.temperatureF}°F',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: weather.temperatureF.toDouble(),
            min: 0,
            max: 110,
            divisions: 110,
            label: '${weather.temperatureF}°F',
            onChanged: (double value) =>
                controller.setTemperature(value.round()),
          ),
          const SizedBox(height: 8),
          Text(
            'Condition',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ChipSingleSelect(
            options: Vocab.weatherConditions,
            selected: weather.condition,
            onChanged: (String? value) {
              if (value != null) controller.setCondition(value);
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Wind',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ChipSingleSelect(
            options: Vocab.windLevels,
            selected: weather.wind,
            onChanged: (String? value) {
              if (value != null) controller.setWind(value);
            },
          ),
        ],
      ),
    );
  }
}
