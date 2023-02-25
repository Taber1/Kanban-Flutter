import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences _prefs;

  TaskRepository(this._prefs);

  Future<List> getTasksByStatus(String status) async {
    final snapshot = await _firestore
        .collection('tasks')
        .where('status', isEqualTo: status)
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map((doc) => doc.data()['name']).toList();
  }

  Future<void> addTask(String taskName) async {
    await _firestore.collection('tasks').add({
      'name': taskName,
      'status': 'todo',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'timer': 0,
      'completedAt': null,
    });
  }

  Future<void> moveTask(
      String taskId, int sourceIndex, int destinationIndex) async {
    final snapshot = await _firestore.collection('tasks').doc(taskId).get();
    final taskData = snapshot.data();
    final taskStatus = taskData!['status'];
    final batch = _firestore.batch();
    if (sourceIndex < destinationIndex) {
      // Moving task forward
      for (int i = sourceIndex; i < destinationIndex; i++) {
        final docId = _prefs.getString('$taskStatus$i');
        batch.update(
            _firestore.collection('tasks').doc(docId), {'index': i + 1});
        _prefs.setString(
            '$taskStatus$i', _prefs.getString('$taskStatus${i + 1}')!);
        _prefs.setString('$taskStatus${i + 1}', docId!);
      }
    } else {
      // Moving task backward
      for (int i = sourceIndex; i > destinationIndex; i--) {
        final docId = _prefs.getString('$taskStatus$i');
        batch.update(
            _firestore.collection('tasks').doc(docId), {'index': i - 1});
        _prefs.setString(
            '$taskStatus$i', _prefs.getString('$taskStatus${i - 1}')!);
        _prefs.setString('$taskStatus${i - 1}', docId!);
      }
    }
    batch.update(_firestore.collection('tasks').doc(taskId),
        {'index': destinationIndex});
    _prefs.setString('$taskStatus$destinationIndex', taskId);
    await batch.commit();
  }

  Future<void> startTimer(String taskId) async {
    final taskDoc = _firestore.collection('tasks').doc(taskId);
    await taskDoc.update({'timer': FieldValue.increment(1)});
    await _prefs.setString('currentTask', taskId);
  }

  Future<int> getCurrentTaskIndex() async {
    final currentTaskId = _prefs.getString('currentTask');
    final currentTaskDoc =
        await _firestore.collection('tasks').doc(currentTaskId).get();
    final currentTaskData = currentTaskDoc.data();
    final currentTaskStatus = currentTaskData!['status'];
    final snapshot = await _firestore
        .collection('tasks')
        .where('status', isEqualTo: currentTaskStatus)
        .orderBy('createdAt')
        .get();
    return snapshot.docs.indexWhere((doc) => doc.id == currentTaskId);
  }

  Future<void> stopTimer() async {
    final currentTaskId = _prefs.getString('currentTask');
    final currentTaskDoc = _firestore.collection('tasks').doc(currentTaskId);
    final currentTaskData = (await currentTaskDoc.get()).data();
    final timerValue = currentTaskData!['timer'];
    final completedAt = DateTime.now().millisecondsSinceEpoch;
    await currentTaskDoc.update({
      'timer': 0,
      'completedAt': completedAt,
    });
    final taskDoc = _firestore.collection('tasks').doc(currentTaskId);
    final taskData = (await taskDoc.get()).data();
    final taskName = taskData!['name'];
    final completedTask = {
      'name': taskName,
      'timer': timerValue,
      'completedAt': completedAt,
    };
    await _firestore.collection('completedTasks').add(completedTask);
    await _prefs.remove('currentTask');
  }

  Future<List<Map<String, dynamic>>> getCompletedTasks() async {
    final snapshot = await _firestore
        .collection('completedTasks')
        .orderBy('completedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> exportToCsv() async {
    final completedTasks = await getCompletedTasks();
    final csvString = List<List<String>>.generate(
      completedTasks.length + 1,
      (index) {
        if (index == 0) {
          return ['Task Name', 'Time Spent', 'Completed At'];
        } else {
          final task = completedTasks[index - 1];
          return [
            task['name'],
            task['timer'].toString(),
            task['completedAt'].toString()
          ];
        }
      },
    ).map((row) => row.join(',')).join('\n');
// TODO: Write the CSV file to disk
  }
}
