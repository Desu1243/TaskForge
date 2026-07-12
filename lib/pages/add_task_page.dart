import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({
    required this.taskType,
    required this.settings,
    this.task,
    super.key,
  });

  final TaskType taskType;
  final AppSettings settings;
  final Task? task;

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _reminderTitleController = TextEditingController();
  final _reminderMessageController = TextEditingController();
  final _targetController = TextEditingController(text: '1');

  final Set<int> _activeWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };
  final Set<int> _reminderWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };

  DateTime? _dueDate;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  HabitPeriod _habitPeriod = HabitPeriod.week;
  bool _reminderEnabled = false;
  bool _positiveCounterEnabled = true;
  bool _negativeCounterEnabled = true;

  bool get _isEditing => widget.task != null;

  String get _typeName => switch (widget.taskType) {
    TaskType.habit => 'habit',
    TaskType.daily => 'daily',
    TaskType.todo => 'to-do',
  };

  @override
  void initState() {
    super.initState();
    _reminderTime = widget.settings.defaultReminderTime;
    final task = widget.task;
    if (task == null) return;

    assert(task.type == widget.taskType);
    _titleController.text = task.title;
    _notesController.text = task.notes;

    final schedule = task.schedule;
    if (schedule is TodoSchedule) {
      _dueDate = schedule.dueDate;
    } else if (schedule is DailySchedule) {
      _activeWeekdays
        ..clear()
        ..addAll(schedule.activeWeekdays);
    } else if (schedule is HabitSchedule) {
      _activeWeekdays
        ..clear()
        ..addAll(schedule.activeWeekdays);
      _targetController.text = schedule.targetCount.toString();
      _habitPeriod = schedule.period;
    }

    final reminder = task.reminder;
    if (reminder != null) {
      _reminderEnabled = true;
      _reminderTime = TimeOfDay(
        hour: reminder.time.hour,
        minute: reminder.time.minute,
      );
      _reminderTitleController.text = reminder.title;
      _reminderMessageController.text = reminder.message;
      if (reminder.activeWeekdays != null) {
        _reminderWeekdays
          ..clear()
          ..addAll(reminder.activeWeekdays!);
      }
    }

    final counters = task.habitCounters;
    if (counters != null) {
      _positiveCounterEnabled = counters.positiveEnabled;
      _negativeCounterEnabled = counters.negativeEnabled;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _reminderTitleController.dispose();
    _reminderMessageController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (time != null) setState(() => _reminderTime = time);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final reminderDays = _reminderWeekdays.intersection(_activeWeekdays);
    if (widget.taskType != TaskType.todo && _activeWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one active day.')),
      );
      return;
    }
    if (_reminderEnabled &&
        widget.taskType != TaskType.todo &&
        reminderDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one reminder day.')),
      );
      return;
    }
    if (widget.taskType == TaskType.habit &&
        !_positiveCounterEnabled &&
        !_negativeCounterEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable at least one habit counter.')),
      );
      return;
    }

    final schedule = switch (widget.taskType) {
      TaskType.todo => TodoSchedule(dueDate: _dueDate),
      TaskType.daily => DailySchedule(activeWeekdays: Set.of(_activeWeekdays)),
      TaskType.habit => HabitSchedule(
        activeWeekdays: Set.of(_activeWeekdays),
        targetCount: int.parse(_targetController.text),
        period: _habitPeriod,
      ),
    };

    final editedTask = widget.task;
    Navigator.pop(
      context,
      Task(
        id: editedTask?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: widget.taskType,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        schedule: schedule,
        habitCounters: widget.taskType == TaskType.habit
            ? HabitCounters(
                positiveEnabled: _positiveCounterEnabled,
                negativeEnabled: _negativeCounterEnabled,
              )
            : null,
        reminder: _reminderEnabled
            ? TaskReminder(
                time: ReminderTime(
                  hour: _reminderTime.hour,
                  minute: _reminderTime.minute,
                ),
                title: _reminderTitleController.text.trim().isEmpty
                    ? _titleController.text.trim()
                    : _reminderTitleController.text.trim(),
                message: _reminderMessageController.text.trim(),
                activeWeekdays: widget.taskType == TaskType.todo
                    ? null
                    : reminderDays,
              )
            : null,
        isCompleted: editedTask?.isCompleted ?? false,
        lastCompletedDate: editedTask?.lastCompletedDate,
        positiveCount: editedTask?.positiveCount ?? 0,
        negativeCount: editedTask?.negativeCount ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_isEditing ? 'Edit' : 'New'} $_typeName'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Title is required.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Scheduling', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (widget.taskType == TaskType.todo) _buildTodoSchedule(),
            if (widget.taskType != TaskType.todo) _buildWeekdaySchedule(),
            if (widget.taskType == TaskType.habit) ...[
              _buildHabitGoal(),
              const SizedBox(height: 16),
              _buildHabitCounters(),
            ],
            const SizedBox(height: 24),
            Text('Reminder', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable reminder'),
              subtitle: widget.settings.notificationsEnabled
                  ? null
                  : const Text('Notifications are disabled in Settings'),
              value: _reminderEnabled,
              onChanged: widget.settings.notificationsEnabled
                  ? (value) => setState(() => _reminderEnabled = value)
                  : null,
            ),
            if (_reminderEnabled) ...[
              if (widget.taskType != TaskType.todo) ...[
                const Text('Reminder days'),
                const SizedBox(height: 8),
                _buildWeekdayPicker(
                  selectedWeekdays: _reminderWeekdays,
                  allowedWeekdays: _activeWeekdays,
                ),
                const SizedBox(height: 8),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                trailing: Text(_reminderTime.format(context)),
                onTap: _pickReminderTime,
              ),
              TextFormField(
                controller: _reminderTitleController,
                decoration: InputDecoration(
                  labelText: 'Notification title',
                  hintText: _titleController.text.trim().isEmpty
                      ? 'Task title (default)'
                      : _titleController.text.trim(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reminderMessageController,
                decoration: const InputDecoration(
                  labelText: 'Notification message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoSchedule() {
    final dateText = _dueDate == null
        ? 'No due date'
        : MaterialLocalizations.of(context).formatMediumDate(_dueDate!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: const Text('Due date'),
      subtitle: Text(dateText),
      trailing: _dueDate == null
          ? null
          : IconButton(
              tooltip: 'Remove due date',
              onPressed: () => setState(() => _dueDate = null),
              icon: const Icon(Icons.clear),
            ),
      onTap: _pickDueDate,
    );
  }

  Widget _buildWeekdaySchedule() {
    return _buildWeekdayPicker(selectedWeekdays: _activeWeekdays);
  }

  Widget _buildWeekdayPicker({
    required Set<int> selectedWeekdays,
    Set<int>? allowedWeekdays,
  }) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: List.generate(labels.length, (index) {
        final weekday = index + 1;
        final enabled = allowedWeekdays?.contains(weekday) ?? true;
        final selected = selectedWeekdays.contains(weekday) && enabled;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: !enabled
                  ? null
                  : () => setState(() {
                      selected
                          ? selectedWeekdays.remove(weekday)
                          : selectedWeekdays.add(weekday);
                    }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  border: Border.all(
                    color: enabled
                        ? Theme.of(context).colorScheme.outline
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: enabled
                        ? null
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHabitGoal() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (widget.taskType != TaskType.habit) return null;
                final target = int.tryParse(value ?? '');
                return target == null || target < 1
                    ? 'Enter a number greater than 0.'
                    : null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<HabitPeriod>(
              initialValue: _habitPeriod,
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
              ),
              items: HabitPeriod.values
                  .map(
                    (period) => DropdownMenuItem(
                      value: period,
                      child: Text(period.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _habitPeriod = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCounters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Available counters'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Positive'),
              showCheckmark: false,
              selected: _positiveCounterEnabled,
              onSelected: (value) {
                setState(() => _positiveCounterEnabled = value);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.remove, size: 18),
              label: const Text('Negative'),
              showCheckmark: false,
              selected: _negativeCounterEnabled,
              onSelected: (value) {
                setState(() => _negativeCounterEnabled = value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
