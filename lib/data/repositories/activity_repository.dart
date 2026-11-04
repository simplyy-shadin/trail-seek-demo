import '../models/activity_record.dart';
import 'local_store.dart';

/// Local activity log. Firestore mirror arrives in task 16.
class ActivityRepository {
  ActivityRepository(this._store);
  final LocalStore _store;

  List<ActivityRecord> load() {
    final list = _store.activities;
    if (list.isNotEmpty) return list;
    // One-time migration from pre-activity session summaries.
    final migrated = _store.history.map((s) => ActivityRecord.fromSessionSummary(s)).toList();
    if (migrated.isNotEmpty) _store.setActivities(migrated);
    return migrated;
  }

  Future<void> save(List<ActivityRecord> all) => _store.setActivities(all);
}
