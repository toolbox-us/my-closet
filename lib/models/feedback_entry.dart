import 'json_utils.dart';

/// Reasons offered when a user dislikes a recommendation.
class DislikeReasons {
  DislikeReasons._();

  static const List<String> all = <String>[
    'Bad color combination',
    'Too formal',
    'Too casual',
    'Too warm',
    'Too cold',
    "Don't like one of the items",
    'Recently worn',
    'Not appropriate',
  ];
}

/// A like/dislike on a recommended outfit.
///
/// Stores the outfit's content signature rather than a whole outfit, so
/// feedback survives even if the outfit itself was never saved.
class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.signature,
    required this.liked,
    required this.createdAt,
    this.reason,
    this.itemIds = const <String>[],
  });

  final String id;

  /// Sorted, pipe-joined item ids - see `Outfit.signature`.
  final String signature;

  final bool liked;
  final String? reason;
  final List<String> itemIds;
  final DateTime createdAt;

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
        id: J.str(json['id']),
        signature: J.str(json['signature']),
        liked: J.boolean(json['liked']),
        reason: J.strOrNull(json['reason']),
        itemIds: J.strList(json['itemIds']),
        createdAt: J.date(json['createdAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'signature': signature,
        'liked': liked,
        'reason': reason,
        'itemIds': itemIds,
        'createdAt': J.dateToJson(createdAt),
      };
}
