import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.settings, super.key});

  final AppSettings settings;

  Future<void> _selectReminderTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: settings.defaultReminderTime,
    );
    if (time != null) settings.setDefaultReminderTime(time);
  }

  Future<void> _selectAutoDeleteDelay(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var enteredHours = settings.autoDeleteCompletedTodosAfterHours.toString();
    final hours = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete completed To-do's after"),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: enteredHours,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (value) => enteredHours = value,
            decoration: const InputDecoration(
              labelText: 'Hours',
              suffixText: 'h',
            ),
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              return parsed == null || parsed < 1
                  ? 'Enter a positive whole number'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, int.parse(enteredHours.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (hours != null) settings.setAutoDeleteCompletedTodosAfterHours(hours);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text('General', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<LaunchScreen>(
            initialValue: settings.launchScreen,
            decoration: const InputDecoration(
              labelText: 'Launch screen',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: LaunchScreen.habits,
                child: Text('Habits'),
              ),
              DropdownMenuItem(
                value: LaunchScreen.dailies,
                child: Text('Dailies'),
              ),
              DropdownMenuItem(
                value: LaunchScreen.todos,
                child: Text("To-do's"),
              ),
            ],
            onChanged: (value) {
              if (value != null) settings.setLaunchScreen(value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<FirstDayOfWeek>(
            initialValue: settings.firstDayOfWeek,
            decoration: const InputDecoration(
              labelText: 'First day of week',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: FirstDayOfWeek.monday,
                child: Text('Monday'),
              ),
              DropdownMenuItem(
                value: FirstDayOfWeek.sunday,
                child: Text('Sunday'),
              ),
            ],
            onChanged: (value) {
              if (value != null) settings.setFirstDayOfWeek(value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.add_task),
            title: const Text('Automatically add a task on launch'),
            subtitle: const Text(
              'Open the new task form before showing your task lists',
            ),
            value: settings.autoAddTaskOnLaunch,
            onChanged: settings.setAutoAddTaskOnLaunch,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TaskType>(
            initialValue: settings.autoAddTaskType,
            decoration: const InputDecoration(
              labelText: 'Default task type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(value: TaskType.habit, child: Text('Habit')),
              DropdownMenuItem(value: TaskType.daily, child: Text('Daily')),
              DropdownMenuItem(value: TaskType.todo, child: Text('To-do')),
            ],
            onChanged: settings.autoAddTaskOnLaunch
                ? (value) {
                    if (value != null) settings.setAutoAddTaskType(value);
                  }
                : null,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.auto_delete_outlined),
            title: const Text("Auto-delete completed To-do's"),
            subtitle: Text(
              'Delete ${settings.autoDeleteCompletedTodosAfterHours} hours after completion',
            ),
            value: settings.autoDeleteCompletedTodos,
            onChanged: settings.setAutoDeleteCompletedTodos,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: settings.autoDeleteCompletedTodos,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Delete after'),
            trailing: Text('${settings.autoDeleteCompletedTodosAfterHours} h'),
            onTap: settings.autoDeleteCompletedTodos
                ? () => _selectAutoDeleteDelay(context)
                : null,
          ),
          const SizedBox(height: 24),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Enable notifications'),
            value: settings.notificationsEnabled,
            onChanged: settings.setNotificationsEnabled,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: settings.notificationsEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Default reminder time'),
            trailing: Text(settings.defaultReminderTime.format(context)),
            onTap: settings.notificationsEnabled
                ? () => _selectReminderTime(context)
                : null,
          ),
          const SizedBox(height: 24),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.fact_check_outlined),
            title: const Text("Review yesterday's skipped Dailies"),
            subtitle: const Text(
              'Ask once per day after opening the task lists',
            ),
            value: settings.reviewSkippedDailies,
            onChanged: settings.setReviewSkippedDailies,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.filter_alt_outlined),
            title: const Text('Auto hide empty habit records in history'),
            value: settings.hideEmptyHabitHistory,
            onChanged: settings.setHideEmptyHabitHistory,
          ),
          const SizedBox(height: 24),
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AppTheme>(
            segments: const [
              ButtonSegment(
                value: AppTheme.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: AppTheme.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
            ],
            selected: {settings.appTheme},
            onSelectionChanged: (selection) {
              settings.setAppTheme(selection.first);
            },
          ),
        ],
      ),
    );
  }
}
