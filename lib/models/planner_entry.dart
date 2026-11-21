import 'json_utils.dart';

/// A saved outfit assigned to a calendar day.
///
/// Keyed by `yyyy-MM-dd` so one day holds at most one planned outfit, which
/// is the behaviour the planner UI expects.
class PlannerEntry {
  const PlannerEntry({
    required this.dateKey,
    required this.outfitId,
    this.note,
  });

  /// `2026-11-21` - see `Dates.key`.
  final String dateKey;

  final String outfitId;
  final String? note;

  factory PlannerEntry.fromJson(Map<String, dynamic> json) => PlannerEntry(
        dateKey: J.str(json['dateKey']),
        outfitId: J.str(json['outfitId']),
        note: J.strOrNull(json['note']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dateKey': dateKey,
        'outfitId': outfitId,
        'note': note,
      };
}
