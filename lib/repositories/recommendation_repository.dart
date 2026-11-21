import '../models/feedback_entry.dart';
import '../models/planner_entry.dart';

/// Stores recommendation feedback. Read back by the engine to nudge future
/// scores, within a capped adjustment.
abstract class FeedbackRepository {
  Future<List<FeedbackEntry>> getAll();

  Future<void> save(FeedbackEntry entry);

  Future<void> clear();
}

/// Stores planner assignments, keyed by `yyyy-MM-dd`.
abstract class PlannerRepository {
  Future<List<PlannerEntry>> getAll();

  Future<PlannerEntry?> forDate(String dateKey);

  Future<void> save(PlannerEntry entry);

  Future<void> delete(String dateKey);

  Future<void> clear();
}
