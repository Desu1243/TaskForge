import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';

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
          const SizedBox(height: 24),
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Enable notifications'),
            subtitle: const Text('Master switch for all task reminders'),
            value: settings.notificationsEnabled,
            onChanged: settings.setNotificationsEnabled,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: settings.notificationsEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Default reminder time'),
            subtitle: const Text('Used when creating a new task'),
            trailing: Text(settings.defaultReminderTime.format(context)),
            onTap: settings.notificationsEnabled
                ? () => _selectReminderTime(context)
                : null,
          ),
          const SizedBox(height: 24),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.filter_alt_outlined),
            title: const Text('Hide empty habit records in history'),
            subtitle: const Text('Hide days with +0 | -0'),
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
