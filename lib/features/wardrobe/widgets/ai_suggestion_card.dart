import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';
import '../../../models/ai_suggestion.dart';

/// Shows what the model proposed, with Accept / Modify / Dismiss.
///
/// Labelled "Suggested Details", never "Detected" or "Identified": the model
/// is confidently wrong often enough - especially on material, which it
/// infers from visual texture and cannot feel - that the wording should not
/// imply certainty. Nothing here is written to the item without the user
/// acting, which is the human-in-the-loop mitigation the ethics write-up
/// rests on.
class AiSuggestionCard extends StatelessWidget {
  const AiSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onAcceptAll,
    required this.onDismiss,
  });

  final AiSuggestion suggestion;
  final VoidCallback onAcceptAll;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unavailable =
        suggestion.errorMessage != null && !suggestion.hasContent;

    final List<_Field> fields = <_Field>[
      _Field('Name', suggestion.suggestedName),
      _Field('Category', suggestion.category),
      _Field('Type', suggestion.subcategory),
      _Field('Primary color', suggestion.primaryColor),
      _Field('Secondary color', suggestion.secondaryColor),
      _Field('Pattern', suggestion.pattern),
      _Field('Material', suggestion.material),
      _Field(
        'Tags',
        suggestion.suggestedTags.isEmpty
            ? null
            : suggestion.suggestedTags.join(', '),
      ),
    ].where((_Field f) => f.value != null).toList();

    return AppCard(
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suggested Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              if (suggestion.isFallback)
                Pill(
                  label: 'Example',
                  icon: Icons.cloud_off,
                  background: theme.colorScheme.surface,
                  foreground: theme.colorScheme.onSurfaceVariant,
                )
              else if (unavailable)
                Pill(
                  label: 'Unavailable',
                  icon: Icons.cloud_off,
                  background: theme.colorScheme.surface,
                  foreground: theme.colorScheme.onSurfaceVariant,
                )
              else
                Pill(
                  label: suggestion.elapsed == null
                      ? 'AI'
                      : '${suggestion.elapsed!.inMilliseconds} ms',
                  icon: Icons.bolt,
                  background: theme.colorScheme.surface,
                  foreground: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            unavailable
                ? suggestion.errorMessage!
                : suggestion.isFallback
                    ? 'This is an example, not an analysis of your photo.'
                        ' Check and edit anything before saving.'
                    : 'Check these before saving - material in particular is '
                        'a guess from texture.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          ...fields.map(
            (_Field field) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 112,
                    child: Text(
                      field.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      field.value!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (fields.isNotEmpty) const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              if (fields.isNotEmpty) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: onAcceptAll,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('Accept ${fields.length} fields'),
                  ),
                ),
              ],
            ],
          ),
          if (fields.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Accepting fills the form - you can still edit every field.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
          if (suggestion.errorMessage != null ||
              suggestion.rawResponse != null) ...<Widget>[
            const SizedBox(height: 8),
            Theme(
              // ExpansionTile draws its own dividers; drop them inside a card.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Technical details',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                children: <Widget>[
                  if (suggestion.errorMessage != null)
                    _MonoBlock(
                      label: 'Error',
                      text: suggestion.errorMessage!,
                    ),
                  if (suggestion.modelUsed.isNotEmpty)
                    _MonoBlock(label: 'Model', text: suggestion.modelUsed),
                  if (suggestion.rawResponse != null)
                    _MonoBlock(
                      label: 'Raw response',
                      text: suggestion.rawResponse!,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field {
  const _Field(this.label, this.value);

  final String label;
  final String? value;
}

/// Monospaced detail block. Exists so that when the API shape changes - and
/// it will - the fix is visible from inside the running app rather than
/// requiring a debugger.
class _MonoBlock extends StatelessWidget {
  const _MonoBlock({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-time disclosure shown before the first AI call.
///
/// Photographs of personal belongings leave the device and reach a
/// third-party API. Saying so once, before it happens, is the minimum - and
/// the AI step stays optional, so declining is a real choice rather than a
/// dead end.
class AiDisclosureDialog extends StatelessWidget {
  const AiDisclosureDialog({super.key, required this.modelName});

  final String modelName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Before you analyze'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'To suggest details, this photo is sent to Google\'s Gemini API '
            '($modelName).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ..._bullets.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('-  '),
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(120, 44),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  static const List<String> _bullets = <String>[
    'Only the image is sent. No name, email or other profile data goes with '
        'it.',
    'Nothing is stored remotely by this app - the response is used once and '
        'discarded.',
    'This step is optional. You can fill the form in by hand.',
    'Suggestions are often wrong. Nothing is saved until you accept it.',
  ];
}
