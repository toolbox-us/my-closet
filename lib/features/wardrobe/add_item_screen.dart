import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/vocab.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/common.dart';
import '../../models/ai_suggestion.dart';
import '../../models/wardrobe_item.dart';
import '../../providers/providers.dart';
import '../../services/ai_service.dart';
import 'widgets/ai_suggestion_card.dart';

/// Add or edit a wardrobe item.
///
/// Pass [itemId] to edit. Only Name, Category and Primary color are required;
/// everything else is optional, so an item can be captured in seconds and
/// enriched later.
class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, this.itemId});

  final String? itemId;

  bool get isEditing => itemId != null && itemId!.isNotEmpty;

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _brand = TextEditingController();
  final TextEditingController _subcategory = TextEditingController();
  final TextEditingController _size = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _price = TextEditingController();

  String _category = 'Tops';
  String _primaryColor = 'Black';
  String? _secondaryColor;
  String? _pattern;
  String? _material;
  String? _fit;
  List<String> _occasions = <String>[];
  List<String> _seasons = <String>[];
  List<String> _styles = <String>[];
  bool _indoor = true;
  bool _outdoor = true;
  bool _favorite = false;

  String? _imagePath;
  Uint8List? _imageBytes;

  AiSuggestion? _suggestion;
  bool _analyzing = false;
  bool _saving = false;
  bool _prefilled = false;

  AttributeSource _source = AttributeSource.manual;

  static const String _disclosureKey = 'ai_disclosure_ack_v1';

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _subcategory.dispose();
    _size.dispose();
    _tags.dispose();
    _notes.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Once the user touches a field after accepting AI values, provenance
  /// becomes "AI-suggested, edited by you" rather than silently staying
  /// "accepted".
  void _markEdited() {
    if (_source == AttributeSource.aiAccepted) {
      _source = AttributeSource.aiEdited;
    }
  }

  void _prefillOnce(WardrobeItem item) {
    if (_prefilled) return;
    _prefilled = true;

    _name.text = item.name;
    _brand.text = item.brand ?? '';
    _subcategory.text = item.subcategory ?? '';
    _size.text = item.size ?? '';
    _tags.text = item.tags.join(', ');
    _notes.text = item.notes ?? '';
    _price.text = item.purchasePrice?.toStringAsFixed(2) ?? '';

    _category = item.category;
    _primaryColor = item.primaryColor;
    _secondaryColor = item.secondaryColor;
    _pattern = item.pattern;
    _material = item.material;
    _fit = item.fit;
    _occasions = List<String>.from(item.occasions);
    _seasons = List<String>.from(item.seasons);
    _styles = List<String>.from(item.styles);
    _indoor = item.indoor;
    _outdoor = item.outdoor;
    _favorite = item.favorite;
    _imagePath = item.imagePath;
    _source = item.attributeSource;
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      // Downscaling at pick time keeps the AI request small - latency and
      // token cost - with no accuracy loss for a single garment.
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: AppConfig.maxImageEdge,
        maxHeight: AppConfig.maxImageEdge,
        imageQuality: AppConfig.imageQuality,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      final String stored = await _persistImage(picked);

      if (!mounted) return;
      setState(() {
        _imagePath = stored;
        _imageBytes = bytes;
        // A new photo invalidates an old suggestion.
        _suggestion = null;
      });
    } catch (error) {
      if (!mounted) return;
      _snack('Could not open that image: $error');
    }
  }

  /// Copies the picked file into the app documents directory.
  ///
  /// The `image_picker` cache path must not be stored on the item: the OS
  /// clears that directory and the photo silently disappears after a restart.
  Future<String> _persistImage(XFile picked) async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory imagesDir = Directory('${docs.path}/item_images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }

    final List<String> parts = picked.path.split('.');
    final String extension = parts.length > 1 ? parts.last : 'jpg';
    final String destination =
        '${imagesDir.path}/${Ids.generate('img')}.$extension';

    await File(picked.path).copy(destination);
    return destination;
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _imagePath = null;
                    _imageBytes = null;
                    _suggestion = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI
  // ---------------------------------------------------------------------------

  Future<bool> _ensureDisclosureAccepted(String modelName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_disclosureKey) ?? false) return true;
    if (!mounted) return false;

    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) =>
          AiDisclosureDialog(modelName: modelName),
    );

    if (accepted ?? false) {
      await prefs.setBool(_disclosureKey, true);
      return true;
    }
    return false;
  }

  Future<void> _analyze() async {
    Uint8List? bytes = _imageBytes;

    // Editing an existing item: the bytes are not in memory, so read them
    // back off disk.
    if (bytes == null && _imagePath != null) {
      try {
        bytes = await File(_imagePath!).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null) {
      _snack('Add a photo first, then analyze it.');
      return;
    }

    final AiService ai = ref.read(aiServiceProvider);

    final bool proceed = await _ensureDisclosureAccepted(ai.modelName);
    if (!proceed) return;

    setState(() => _analyzing = true);
    final AiSuggestion result = await ai.analyzeWardrobeItem(bytes);
    if (!mounted) return;

    setState(() {
      _analyzing = false;
      _suggestion = result;
    });
  }

  void _acceptSuggestion(AiSuggestion suggestion) {
    setState(() {
      if (suggestion.suggestedName != null && _name.text.trim().isEmpty) {
        _name.text = suggestion.suggestedName!;
      }
      if (suggestion.subcategory != null) {
        _subcategory.text = suggestion.subcategory!;
      }
      if (suggestion.category != null) _category = suggestion.category!;
      if (suggestion.primaryColor != null) {
        _primaryColor = suggestion.primaryColor!;
      }
      if (suggestion.secondaryColor != null) {
        _secondaryColor = suggestion.secondaryColor;
      }
      if (suggestion.pattern != null) _pattern = suggestion.pattern;
      if (suggestion.material != null) _material = suggestion.material;

      if (suggestion.suggestedTags.isNotEmpty) {
        final Set<String> merged = <String>{
          ..._tags.text
              .split(',')
              .map((String t) => t.trim())
              .where((String t) => t.isNotEmpty),
          ...suggestion.suggestedTags,
        };
        _tags.text = merged.join(', ');

        // Tags come from the style/occasion vocabulary, so anything that maps
        // cleanly can also populate the scored fields.
        for (final String tag in suggestion.suggestedTags) {
          final String spaced = tag.replaceAll('-', ' ');
          final String? style = Vocab.match(spaced, Vocab.styles);
          if (style != null && !_styles.contains(style)) _styles.add(style);
          final String? occasion = Vocab.match(spaced, Vocab.occasions);
          if (occasion != null && !_occasions.contains(occasion)) {
            _occasions.add(occasion);
          }
        }
      }

      // A fallback is an example, not a model output - do not claim AI
      // provenance for it.
      _source = suggestion.isFallback
          ? AttributeSource.manual
          : AttributeSource.aiAccepted;
      _suggestion = null;
    });

    _snack('Suggestions applied. Edit anything before saving.');
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final List<String> tags = _tags.text
        .split(',')
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty)
        .toList();

    final WardrobeItem item = WardrobeItem(
      id: widget.isEditing ? widget.itemId! : Ids.generate('item'),
      name: _name.text.trim(),
      category: _category,
      primaryColor: _primaryColor,
      subcategory: _nullIfBlank(_subcategory.text),
      brand: _nullIfBlank(_brand.text),
      secondaryColor: _secondaryColor,
      pattern: _pattern,
      material: _material,
      size: _nullIfBlank(_size.text),
      fit: _fit,
      occasions: _occasions,
      seasons: _seasons,
      styles: _styles,
      indoor: _indoor,
      outdoor: _outdoor,
      tags: tags,
      notes: _nullIfBlank(_notes.text),
      purchasePrice: double.tryParse(_price.text.trim()),
      favorite: _favorite,
      imagePath: _imagePath,
      timesWorn: _existing?.timesWorn ?? 0,
      lastWorn: _existing?.lastWorn,
      attributeSource: _source,
    );

    await ref.read(wardrobeControllerProvider.notifier).save(item);

    if (!mounted) return;
    setState(() => _saving = false);

    // Grab the messenger before popping: after the pop this State is
    // unmounted and `context` can no longer be used to find one.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing ? 'Item updated.' : 'Item added to wardrobe.',
        ),
      ),
    );
  }

  static String? _nullIfBlank(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  WardrobeItem? _existing;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AiService ai = ref.read(aiServiceProvider);

    if (widget.isEditing) {
      final List<WardrobeItem> items =
          ref.watch(wardrobeControllerProvider).valueOrNull ??
              const <WardrobeItem>[];
      for (final WardrobeItem candidate in items) {
        if (candidate.id == widget.itemId) {
          _existing = candidate;
          _prefillOnce(candidate);
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit item' : 'Add item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: <Widget>[
            // --- Photo + AI ---------------------------------------------
            _photoSection(theme, ai),

            const SizedBox(height: 28),
            const SectionHeader(
              title: 'Basics',
              subtitle: 'Name, category and primary color are required.',
            ),

            LabeledField(
              label: 'Name',
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Navy Linen Shirt',
                ),
                onChanged: (_) => _markEdited(),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Give the item a name'
                        : null,
              ),
            ),

            LabeledField(
              label: 'Category',
              child: ChipSingleSelect(
                options: Vocab.categories,
                selected: _category,
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                    _markEdited();
                  });
                },
              ),
            ),

            LabeledField(
              label: 'Type',
              optional: true,
              child: TextFormField(
                controller: _subcategory,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Oxford Shirt, Chelsea Boots',
                ),
                onChanged: (_) => _markEdited(),
              ),
            ),

            LabeledField(
              label: 'Brand',
              optional: true,
              child: TextFormField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. Uniqlo'),
                onChanged: (_) => _markEdited(),
              ),
            ),

            const SizedBox(height: 12),
            const SectionHeader(title: 'Appearance'),

            LabeledField(
              label: 'Primary color',
              child: ChipSingleSelect(
                options: Vocab.colors,
                selected: _primaryColor,
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _primaryColor = value;
                    _markEdited();
                  });
                },
              ),
            ),

            LabeledField(
              label: 'Secondary color',
              optional: true,
              child: ChipSingleSelect(
                options: Vocab.colors,
                selected: _secondaryColor,
                allowNone: true,
                onChanged: (String? value) => setState(() {
                  _secondaryColor = value;
                  _markEdited();
                }),
              ),
            ),

            LabeledField(
              label: 'Pattern',
              optional: true,
              child: ChipSingleSelect(
                options: Vocab.patterns,
                selected: _pattern,
                allowNone: true,
                onChanged: (String? value) => setState(() {
                  _pattern = value;
                  _markEdited();
                }),
              ),
            ),

            LabeledField(
              label: 'Material',
              optional: true,
              child: ChipSingleSelect(
                options: Vocab.materials,
                selected: _material,
                allowNone: true,
                onChanged: (String? value) => setState(() {
                  _material = value;
                  _markEdited();
                }),
              ),
            ),

            const SizedBox(height: 12),
            const SectionHeader(title: 'Fit'),

            LabeledField(
              label: 'Size',
              optional: true,
              child: TextFormField(
                controller: _size,
                decoration: const InputDecoration(hintText: 'e.g. M, 32, 10'),
                onChanged: (_) => _markEdited(),
              ),
            ),

            LabeledField(
              label: 'Fit',
              optional: true,
              child: ChipSingleSelect(
                options: Vocab.fits,
                selected: _fit,
                allowNone: true,
                onChanged: (String? value) => setState(() => _fit = value),
              ),
            ),

            const SizedBox(height: 12),
            const SectionHeader(
              title: 'Usage',
              subtitle: 'These drive the recommendation engine.',
            ),

            LabeledField(
              label: 'Occasions',
              optional: true,
              child: ChipMultiSelect(
                options: Vocab.occasions,
                selected: _occasions,
                onChanged: (List<String> next) =>
                    setState(() => _occasions = next),
              ),
            ),

            LabeledField(
              label: 'Styles',
              optional: true,
              child: ChipMultiSelect(
                options: Vocab.styles,
                selected: _styles,
                onChanged: (List<String> next) =>
                    setState(() => _styles = next),
              ),
            ),

            LabeledField(
              label: 'Seasons',
              optional: true,
              child: ChipMultiSelect(
                options: Vocab.seasons,
                selected: _seasons,
                onChanged: (List<String> next) =>
                    setState(() => _seasons = next),
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suitable indoors'),
              value: _indoor,
              onChanged: (bool value) => setState(() => _indoor = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suitable outdoors'),
              value: _outdoor,
              onChanged: (bool value) => setState(() => _outdoor = value),
            ),

            const SizedBox(height: 20),
            const SectionHeader(title: 'Extras'),

            LabeledField(
              label: 'Tags',
              optional: true,
              child: TextFormField(
                controller: _tags,
                decoration: const InputDecoration(
                  hintText: 'comma separated, e.g. work, layering',
                ),
                onChanged: (_) => _markEdited(),
              ),
            ),

            LabeledField(
              label: 'Notes',
              optional: true,
              child: TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Anything worth remembering',
                ),
              ),
            ),

            LabeledField(
              label: 'Purchase price',
              optional: true,
              child: TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  hintText: '0.00',
                ),
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mark as favorite'),
              value: _favorite,
              onChanged: (bool value) => setState(() => _favorite = value),
            ),

            if (_source.involvedAi) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Pill(label: _source.label, icon: Icons.auto_awesome),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isEditing ? 'Save changes' : 'Add to wardrobe'),
          ),
        ),
      ),
    );
  }

  Widget _photoSection(ThemeData theme, AiService ai) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _showImageSourceSheet,
              child: _imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 34,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add a photo',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Camera or gallery - optional',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) =>
                          Center(
                        child: Text(
                          'Could not load that photo',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _analyzing ? null : _showImageSourceSheet,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(_imagePath == null ? 'Add photo' : 'Change'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: (_analyzing || _imagePath == null) ? null : _analyze,
                icon: _analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_analyzing ? 'Analyzing...' : 'Analyze with AI'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
          ],
        ),

        if (!ai.isLive) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No API key configured - analysis will return an example. '
                  'See README to enable Gemini.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],

        if (_suggestion != null) ...<Widget>[
          const SizedBox(height: 16),
          AiSuggestionCard(
            suggestion: _suggestion!,
            onAcceptAll: () => _acceptSuggestion(_suggestion!),
            onDismiss: () => setState(() => _suggestion = null),
          ),
        ],
      ],
    );
  }
}
