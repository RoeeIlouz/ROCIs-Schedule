import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/tasks/synced_tasks_provider.dart';
import 'package:rocis_schedule/shared/models/synced_task_model.dart';
import 'package:rocis_schedule/shared/services/tasks_firestore_service.dart';

class _FakeTasksService extends TasksFirestoreService {
  int fetches = 0;

  @override
  Future<List<SyncedTask>> fetchTasks() async {
    fetches++;
    return [];
  }
}

void main() {
  test('loads tasks each time the ROCIs Tasks sign-in changes', () async {
    final service = _FakeTasksService();
    final authChanges = StreamController<Object?>();
    final provider = SyncedTasksProvider(
      tasksService: service,
      uid: 'u1',
      tasksAuthChanges: authChanges.stream,
    );

    authChanges.add(null); // First state: not signed in to ROCIs Tasks yet.
    authChanges.add(Object()); // Signed in after the Schedule sign-in.
    await pumpEventQueue();
    expect(service.fetches, 2);

    provider.dispose();
    authChanges.add(null);
    await pumpEventQueue();
    expect(service.fetches, 2);
    await authChanges.close();
  });

  test('guests never listen or load', () async {
    final service = _FakeTasksService();
    final authChanges = StreamController<Object?>.broadcast();
    SyncedTasksProvider(
      tasksService: service,
      tasksAuthChanges: authChanges.stream,
    );

    expect(authChanges.hasListener, isFalse);
    authChanges.add(Object());
    await pumpEventQueue();
    expect(service.fetches, 0);
    await authChanges.close();
  });
}
