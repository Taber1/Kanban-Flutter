import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repo/task/task_repo.dart';

// Defining the events for the bloc
abstract class KanbanEvent {}

class LoadTasksEvent extends KanbanEvent {}

class AddTaskEvent extends KanbanEvent {
  final String taskName;

  AddTaskEvent(this.taskName);
}

class MoveTaskEvent extends KanbanEvent {
  final String taskId;
  final int sourceIndex;
  final int destinationIndex;

  MoveTaskEvent(this.taskId, this.sourceIndex, this.destinationIndex);
}

class StartTimerEvent extends KanbanEvent {
  final String taskId;

  StartTimerEvent(this.taskId);
}

class StopTimerEvent extends KanbanEvent {}

class CompleteTaskEvent extends KanbanEvent {}

// Defining the states for the bloc
abstract class KanbanState {}

class InitialState extends KanbanState {}

class LoadingState extends KanbanState {}

class LoadedState extends KanbanState {
  final List<String> todoTasks;
  final List<String> inProgressTasks;
  final List<String> doneTasks;

  LoadedState(this.todoTasks, this.inProgressTasks, this.doneTasks);
}

class ErrorState extends KanbanState {}

// Defining the BLoC
class KanbanBloc extends Bloc<KanbanEvent, KanbanState> {
  List<String> todoTasks = [];
  List<String> inProgressTasks = [];
  List<String> doneTasks = [];
  late SharedPreferences prefs;
  late Timer timer;
  String? currentTaskId;
  int? currentTaskIndex;
  int currentTaskTime = 0;
  bool isRunning = false;

  KanbanBloc() : super(InitialState());

  Stream<KanbanState> mapEventToState(KanbanEvent event) async* {
    if (event is LoadTasksEvent) {
      yield LoadingState();
      try {
        await _loadTasks();
        yield LoadedState(todoTasks, inProgressTasks, doneTasks);
      } catch (_) {
        yield ErrorState();
      }
    } else if (event is AddTaskEvent) {
      try {
        await _addTask(event.taskName);
        yield LoadedState(todoTasks, inProgressTasks, doneTasks);
      } catch (_) {
        yield ErrorState();
      }
    } else if (event is MoveTaskEvent) {
      try {
        await _moveTask(
            event.taskId, event.sourceIndex, event.destinationIndex);
        yield LoadedState(todoTasks, inProgressTasks, doneTasks);
      } catch (_) {
        yield ErrorState();
      }
    } else if (event is StartTimerEvent) {
      _startTimer(event.taskId);
    } else if (event is StopTimerEvent) {
      _stopTimer();
    } else if (event is CompleteTaskEvent) {
      try {
        await _completeTask();
        yield LoadedState(todoTasks, inProgressTasks, doneTasks);
      } catch (_) {
        yield ErrorState();
      }
    }
  }

  Future<void> _loadTasks() async {
    // Load tasks from Firebase
    QuerySnapshot tasksSnapshot =
        await FirebaseFirestore.instance.collection('tasks').get();
    tasksSnapshot.docs.forEach((doc) {
      switch (doc['status']) {
        case 'todo':
          todo.add(doc['name']);
          break;
        case 'inProgress':
          inProgressTasks.add(doc['name']);
          break;
        case 'done':
          doneTasks.add(doc['name']);
          break;
      }
    });

// Load tasks from shared preferences
    prefs = await SharedPreferences.getInstance();
    List<String> completedTasks = prefs.getStringList('completedTasks') ?? [];
    completedTasks.forEach((task) {
      List<String> parts = task.split(':');
      doneTasks.add(parts[0]);
    });
  }

  Future<void> _addTask(String taskName) async {
// Add task to Firebase
    await FirebaseFirestore.instance
        .collection('tasks')
        .add({'name': taskName, 'status': 'todo'});

    todoTasks.add(taskName);
  }

  Future<void> _moveTask(
      String taskId, int sourceIndex, int destinationIndex) async {
// Move task in Firebase
    String status = "";
    if (destinationIndex == 0) {
      status = 'todo';
    } else if (destinationIndex == 1) {
      status = 'inProgress';
    } else if (destinationIndex == 2) {
      status = 'done';
    }
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .update({'status': status});

// Move task in the local list
    String taskName = _getTaskNameById(taskId);
    if (sourceIndex == 0) {
      todoTasks.remove(taskName);
    } else if (sourceIndex == 1) {
      inProgressTasks.remove(taskName);
    } else if (sourceIndex == 2) {
      doneTasks.remove(taskName);
    }
    if (destinationIndex == 0) {
      todoTasks.insert(0, taskName);
    } else if (destinationIndex == 1) {
      inProgressTasks.insert(0, taskName);
    } else if (destinationIndex == 2) {
      doneTasks.insert(0, taskName);
    }
  }

  void _startTimer(String taskId) {
// Start the timer
    if (isRunning) {
      _stopTimer();
    }
    currentTaskId = taskId;
    currentTaskIndex = _getTaskIndexById(taskId);
    currentTaskTime = prefs.getInt('taskTime$currentTaskIndex') ?? 0;
    isRunning = true;
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      currentTaskTime++;
    });
  }

  void _stopTimer() {
// Stop the timer
    if (!isRunning) {
      return;
    }
    timer.cancel();
    prefs.setInt('taskTime$currentTaskIndex', currentTaskTime);
    isRunning = false;
    currentTaskId = null;
    currentTaskIndex = null;
    currentTaskTime = 0;
  }

  Future<void> _completeTask() async {
// Complete the task in Firebase
    String taskId = _getTaskIdByName(doneTasks.first);
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).delete();

// Add the completed task to shared preferences
    String taskString =
        '${doneTasks.first}:${prefs.getInt('taskTime$currentTaskIndex')}';
    List<String> completedTasks = prefs.getStringList('completedTasks') ?? [];
    completedTasks.add(taskString);
    prefs.setStringList('completedTasks', completedTasks);

// Remove the completed task from the local list
    doneTasks.removeAt(0);
  }

  String _getTaskIdByName(String name) {
// Get the Firebase document ID for a task given its name
    QuerySnapshot snapshot = FirebaseFirestore.instance
        .collection('tasks')
        .where('name', isEqualTo: name)
        .limit(1)
        .get() as QuerySnapshot<Object?>;
    return snapshot.docs[0].id;
  }

  String _getTaskNameById(String id) {
// Get the name of a task given its Firebase document ID
    QuerySnapshot snapshot = FirebaseFirestore.instance
        .collection('tasks')
        .where(FieldPath.documentId, isEqualTo: id)
        .limit(1)
        .get() as QuerySnapshot<Object?>;
    return snapshot.docs[0]['name'];
  }

  int _getTaskIndexById(String id) {
// Get the index of a task in the shared preferences list given its Firebase document ID
    List<String> completedTasks = prefs.getStringList('completedTasks') ?? [];
    for (int i = 0; i < completedTasks.length; i++) {
      List<String> parts = completedTasks[i].split(':');
      if (_getTaskIdByName(parts[0]) == id) {
        return i;
      }
    }
    return -1;
  }
}

class Task {
  final String id;
  final String name;
  final String status;

  Task({required this.id, required this.name, required this.status});

  factory Task.fromMap(Map<String, dynamic> data, String id) {
    String name = data['name'];
    String status = data['status'];
    return Task(id: id, name: name, status: status);
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'status': status};
  }
}

abstract class TaskEvent {}

class TaskLoadTasksEvent extends TaskEvent {}

class TaskAddTaskEvent extends TaskEvent {
  final String taskName;

  TaskAddTaskEvent(this.taskName);
}

class TaskMoveTaskEvent extends TaskEvent {
  final String taskId;
  final int sourceIndex;
  final int destinationIndex;

  TaskMoveTaskEvent(this.taskId, this.sourceIndex, this.destinationIndex);
}

class TaskStartTimerEvent extends TaskEvent {
  final String taskId;

  TaskStartTimerEvent(this.taskId);
}

class TaskStopTimerEvent extends TaskEvent {}

class TaskCompleteTaskEvent extends TaskEvent {}

abstract class TaskState {}

class TaskLoadingState extends TaskState {}

class TaskLoadedState extends TaskState {
  final List<String> todoTasks;
  final List<String> inProgressTasks;
  final List<String> doneTasks;

  TaskLoadedState(this.todoTasks, this.inProgressTasks, this.doneTasks);
}

class TaskAddedState extends LoadedState {
  TaskAddedState(List<String> todoTasks, List<String> inProgressTasks,
      List<String> doneTasks)
      : super(todoTasks, inProgressTasks, doneTasks);
}

class TaskMovedState extends LoadedState {
  TaskMovedState(List<String> todoTasks, List<String> inProgressTasks,
      List<String> doneTasks)
      : super(todoTasks, inProgressTasks, doneTasks);
}

class TimerStartedState extends LoadedState {
  final int currentTaskIndex;

  TimerStartedState(List<String> todoTasks, List<String> inProgressTasks,
      List<String> doneTasks, this.currentTaskIndex)
      : super(todoTasks, inProgressTasks, doneTasks);
}

class TimerStoppedState extends LoadedState {
  TimerStoppedState(List<String> todoTasks, List<String> inProgressTasks,
      List<String> doneTasks)
      : super(todoTasks, inProgressTasks, doneTasks);
}

class TaskCompletedState extends LoadedState {
  TaskCompletedState(List<String> todoTasks, List<String> inProgressTasks,
      List<String> doneTasks)
      : super(todoTasks, inProgressTasks, doneTasks);
}

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository taskRepository;

  TaskBloc(this.taskRepository) : super(TaskLoadingState());

  @override
  Stream<TaskState> mapEventToState(TaskEvent event) async* {
    if (event is LoadTasksEvent) {
      yield TaskLoadingState();
      try {
        List<String>? todoTasks =
            (await taskRepository.getTasksByStatus('todo')).cast<String>();
        List<String>? inProgressTasks =
            (await taskRepository.getTasksByStatus('inProgress'))
                .cast<String>();
        List<String>? doneTasks =
            (await taskRepository.getTasksByStatus('done')).cast<String>();
        yield TaskLoadedState(todoTasks, inProgressTasks, doneTasks);
      } catch (e) {
        yield TaskLoadingState();
      }
    } else if (event is AddTaskEvent) {
      yield TaskLoadingState();
      try {
        await taskRepository.addTask(event.taskName);
        List<String> todoTasks = await taskRepository.getTasksByStatus('todo');
        List<String> inProgressTasks =
            await taskRepository.getTasksByStatus('inProgress');
        List<String> doneTasks = await taskRepository.getTasksByStatus('done');
        yield TaskAddedState(todoTasks, inProgressTasks, doneTasks);
      } catch (e) {
        yield TaskLoadingState();
      }
    } else if (event is MoveTaskEvent) {
      yield TaskLoadingState();
      try {
        await taskRepository.moveTask(
            event.taskId, event.sourceIndex, event.destinationIndex);
        List<String> todoTasks = await taskRepository.getTasksByStatus('todo');
        List<String> inProgressTasks =
            await taskRepository.getTasksByStatus('inProgress');
        List<String> doneTasks = await taskRepository.getTasksByStatus('done');
        yield TaskMovedState(todoTasks, inProgressTasks, doneTasks);
      } catch (e) {
        yield TaskLoadingState();
      }
    } else if (event is StartTimerEvent) {
      yield TaskLoadingState();
      try {
        await taskRepository.startTimer(event.taskId);
        int currentTaskIndex = await taskRepository.getCurrentTaskIndex();
        List<String> todoTasks = await taskRepository.getTasksByStatus('todo');
        List<String> inProgressTasks =
            await taskRepository.getTasksByStatus('inProgress');
        List<String> doneTasks = await taskRepository.getTasksByStatus('done');
        yield TimerStartedState(
            todoTasks, inProgressTasks, doneTasks, currentTaskIndex);
      } catch (e) {
        yield TaskLoadingState();
      }
    } else if (event is StopTimerEvent) {
      yield TaskLoadingState();
      try {
        await taskRepository.stopTimer();
        List<String> todoTasks = await taskRepository.getTasksByStatus('todo');
        List<String> inProgressTasks =
            await taskRepository.getTasksByStatus('inProgress');
        List<String> doneTasks = await taskRepository.getTasksByStatus('done');
        yield TimerStoppedState(todoTasks, inProgressTasks, doneTasks);
      } catch (e) {
        yield TaskLoadingState();
      }
    } else if (event is CompleteTaskEvent) {
      yield TaskLoadingState();
      try {
        await taskRepository.completeTask();
        List<String> todoTasks = await taskRepository.getTasksByStatus('todo');
        List<String> inProgressTasks =
            await taskRepository.getTasksByStatus('inProgress');
        List<String> doneTasks = await taskRepository.getTasksByStatus('done');
        yield TaskCompletedState(todoTasks, inProgressTasks, doneTasks);
      } catch (e) {
        yield TaskLoadingState();
      }
    }
  }
}
