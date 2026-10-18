import 'package:flutter_test/flutter_test.dart';
import 'package:reset_app/models/checklist_entry.dart';

void main() {
  Map<String, dynamic> row() {
    return {
      'id': 'check-1',
      'user_id': 'user-1',
      'task_id': 'task-1',
      'check_date': '2026-10-17',
      'completed': true,
      'completed_at': '2026-10-17T02:15:00.000Z',
      'created_at': '2026-10-17T00:00:05.000Z',
      'updated_at': '2026-10-17T02:15:00.000Z',
    };
  }

  test('ChecklistEntry.fromMap parses full row', () {
    final entry = ChecklistEntry.fromMap(row());

    expect(entry.id, 'check-1');
    expect(entry.userId, 'user-1');
    expect(entry.taskId, 'task-1');
    expect(entry.checkDate, DateTime(2026, 10, 17));
    expect(entry.completed, isTrue);
    expect(entry.completedAt, DateTime.utc(2026, 10, 17, 2, 15));
    expect(entry.createdAt, DateTime.utc(2026, 10, 17, 0, 0, 5));
    expect(entry.updatedAt, DateTime.utc(2026, 10, 17, 2, 15));
  });

  test('ChecklistEntry.fromMap defaults optional values', () {
    final entry = ChecklistEntry.fromMap({
      'id': 'check-2',
      'user_id': 'user-1',
      'task_id': 'task-2',
      'check_date': '2026-10-18',
    });

    expect(entry.completed, isFalse);
    expect(entry.completedAt, isNull);
    expect(entry.createdAt, isNull);
    expect(entry.updatedAt, isNull);
  });

  test('ChecklistEntry.toMap serializes check_date as yyyy-MM-dd', () {
    final entry = ChecklistEntry.fromMap(row());
    final map = entry.toMap();

    expect(map['check_date'], '2026-10-17');
    expect(map['completed'], isTrue);
    expect(map['completed_at'], '2026-10-17T02:15:00.000Z');
  });

  test('ChecklistEntry.toMap round trips through fromMap', () {
    final entry = ChecklistEntry.fromMap(row());
    final restored = ChecklistEntry.fromMap(entry.toMap());

    expect(restored.id, entry.id);
    expect(restored.userId, entry.userId);
    expect(restored.taskId, entry.taskId);
    expect(restored.checkDate, entry.checkDate);
    expect(restored.completed, entry.completed);
    expect(restored.completedAt, entry.completedAt);
  });
}
