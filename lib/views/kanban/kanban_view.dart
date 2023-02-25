import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/kanban/kanban_event.dart';
import '../../repo/task/task_repo.dart';

class KanbanBoard extends StatelessWidget {
  final TaskRepository _taskRepository = TaskRepository();

  KanbanBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskBloc>(
      create: (context) => TaskBloc(_taskRepository),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Kanban Board'),
            bottom: TabBar(
              tabs: [
                Tab(text: 'To Do'),
                Tab(text: 'In Progress'),
                Tab(text: 'Done'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              TaskList(status: 'todo'),
              TaskList(status: 'inProgress'),
              TaskList(status: 'done'),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddTaskDialog(),
              );
            },
            child: Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}

class TaskList extends StatelessWidget {
  final String status;

  TaskList({required this.status});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (BuildContext context, TaskState state) {
        if (state is TaskLoadSuccess) {
          final tasks = state.tasks
              .where((task) => task.status == status)
              .toList(); // get tasks with specified status
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                child: ListTile(
                    title: Text(task.name),
                    subtitle: Text(task.timeSpent.toString()),
                    onTap: () {}),
              );
            },
          );
        } else {
          return Container();
        }
      },
    );
  }
}

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Task'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(hintText: 'Task name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text;
            BlocProvider.of<TaskBloc>(context).add(AddTask(name));
            Navigator.of(context).pop();
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}
