import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanban Board',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: KanbanBoard(),
    );
  }
}

class KanbanBoard extends StatefulWidget {
  @override
  _KanbanBoardState createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  List<List<dynamic>> csvData = [
    ['Task Name', 'Description', 'Time Spent', 'Date Completed']
  ];

  List<Task> toDoTasks = [
    Task(name: 'Task 1', description: 'Description of Task 1'),
    Task(name: 'Task 2', description: 'Description of Task 2'),
    Task(name: 'Task 3', description: 'Description of Task 3'),
  ];

  List<Task> inProgressTasks = [];

  List<Task> doneTasks = [];

  final TextEditingController _taskNameController = TextEditingController();

  final TextEditingController _taskDescriptionController =
      TextEditingController();

  void _addTask(String taskName, String taskDescription) {
    setState(() {
      toDoTasks.add(Task(name: 'taskName', description: taskDescription));
    });
    Navigator.pop(context);
  }

  void _stopTask(Task task) {
    setState(() {
      task.isRunning = false;
      final timeSpent =
          DateTime.now().difference(task.startTime!).inSeconds / 60.0;
      task.timeSpent += timeSpent as Duration;
      _addToCsv(task.name, task.description, task.timeSpent as double,
          DateTime.now());
    });
  }

  void _moveTask(Task task, List<Task> targetList) {
    setState(() {
      if (toDoTasks.contains(task)) {
        toDoTasks.remove(task);
      } else if (inProgressTasks.contains(task)) {
        inProgressTasks.remove(task);
      } else if (doneTasks.contains(task)) {
        doneTasks.remove(task);
      }
      targetList.add(task);
    });
  }

  void _showNewTaskDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _taskNameController,
                decoration: InputDecoration(
                  hintText: 'Task Name',
                ),
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _taskDescriptionController,
                decoration: InputDecoration(
                  hintText: 'Task Description',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                _addTask(
                    _taskNameController.text, _taskDescriptionController.text);
              },
            ),
          ],
        );
      },
    );
  }

  void _addToCsv(String name, String description, double timeSpent,
      DateTime dateCompleted) async {
    List<dynamic> newRow = [name, description, timeSpent, dateCompleted];
    csvData.add(newRow);
    final dir = await getApplicationDocumentsDirectory();
    final path = dir.path + '/tasks.csv';
    final file = File(path);
    String csv = const ListToCsvConverter().convert(csvData);
    file.writeAsString(csv);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kanban Board'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.file_download),
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final path = dir.path + '/tasks.csv';
              final file = File(path);
              String csv = const ListToCsvConverter().convert(csvData);
              file.writeAsString(csv);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('CSV file exported to ${dir.path}/tasks.csv'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _buildKanbanColumn('To Do', toDoTasks),
                _buildKanbanColumn('In Progress', inProgressTasks),
                _buildKanbanColumn('Done', doneTasks),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                ElevatedButton(
                  child: Text('New Task'),
                  onPressed: _showNewTaskDialog,
                ),
                ElevatedButton(
                  child: Text('Export CSV'),
                  onPressed: () async {
                    final dir = await getApplicationDocumentsDirectory();
                    final path = dir.path + '/tasks.csv';
                    final file = File(path);
                    String csv = const ListToCsvConverter().convert(csvData);
                    file.writeAsString(csv);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('CSV file exported to ${dir.path}/tasks.csv'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String title, List<Task> tasks) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (BuildContext context, int index) {
                  final task = tasks[index];
                  return Card(
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          title: Text(task.name),
                          subtitle: Text(task.description),
                          trailing: IconButton(
                            icon: task.isRunning
                                ? Icon(Icons.pause)
                                : Icon(Icons.play_arrow),
                            onPressed: () {
                              if (task.isRunning) {
                                _stopTask(task);
                              } else {
                                _startTask(task);
                              }
                            },
                          ),
                        ),
                        ButtonBar(
                          children: <Widget>[
                            TextButton(
                              child: const Text('Delete'),
                              onPressed: () {
                                setState(() {
                                  tasks.remove(task);
                                });
                              },
                            ),
                            TextButton(
                              child: const Text('Edit'),
                              onPressed: () {},
                            ),
                            TextButton(
                              child: const Text('Move'),
                              onPressed: () {
                                _showMoveTaskDialog(task);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<KanbanColumn> kanbanColumns = [];
  void _showMoveTaskDialog(Task task) {
    final currentIndex =
        kanbanColumns.indexWhere((element) => element.tasks.contains(task));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Move Task'),
          content: SingleChildScrollView(
            child: ListBody(
              children: kanbanColumns
                  .map(
                    (column) => RadioListTile(
                      title: Text(column.title),
                      value: column,
                      groupValue: kanbanColumns[currentIndex],
                      onChanged: (value) {
                        setState(() {
                          kanbanColumns[currentIndex].tasks.remove(task);
                          value!.tasks.add(task);
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  void _startTask(Task task) {
    setState(() {
      task.isRunning = true;
      task.startTime = DateTime.now();
    });
  }
}

class KanbanColumn {
  final String title;
  final List<Task> tasks;

  KanbanColumn({required this.title, required this.tasks});
}

class Task {
  final String name;
  final String description;
  Duration timeSpent;
  bool isRunning;
  DateTime? startTime;

  Task({
    required this.name,
    this.description = '',
    this.timeSpent = const Duration(seconds: 0),
    this.isRunning = false,
    this.startTime,
  });
}
