import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/pages/task_history_page.dart';
import 'package:taskforge/widgets/task_tags.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({
    required this.taskType,
    required this.settings,
    this.task,
    this.onDelete,
    this.onHistoryChanged,
    super.key,
  });

  final TaskType taskType;
  final AppSettings settings;
  final Task? task;
  final VoidCallback? onDelete;
  final Future<void> Function(Task)? onHistoryChanged;

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _targetController = TextEditingController(text: '1');
  final _positiveCountController = TextEditingController(text: '0');
  final _negativeCountController = TextEditingController(text: '0');

  final Set<int> _activeWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };
  final List<TaskReminder> _reminders = [];
  final _reminderEditorKey = GlobalKey();
  String? _editingReminderId;
  DateTime _reminderDate = Task.dateOnly(DateTime.now());
  bool _untilCompleted = false;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  HabitPeriod _habitPeriod = HabitPeriod.week;
  bool _positiveCounterEnabled = true;
  bool _negativeCounterEnabled = true;
  bool _dailyMonthly = false;
  final Set<int> _activeMonthDays = {DateTime.now().day};
  Set<String> _tagIds = {};

  bool get _isMonthlyDaily =>
      widget.taskType == TaskType.daily && _dailyMonthly;

  bool get _isEditing => widget.task != null;

  String get _typeName => switch (widget.taskType) {
    TaskType.habit => 'habit',
    TaskType.daily => 'daily',
    TaskType.todo => 'to-do',
  };

  @override
  void initState() {
    super.initState();
    _reminderTime = widget.settings.defaultReminderTimeAt(DateTime.now());
    final task = widget.task;
    if (task == null) return;

    assert(task.type == widget.taskType);
    _titleController.text = task.title;
    _notesController.text = task.notes;
    _tagIds = Set.of(task.tagIds);

    final schedule = task.schedule;
    if (schedule is DailySchedule) {
      _dailyMonthly = schedule.isMonthly;
      if (schedule.isMonthly) {
        _activeMonthDays
          ..clear()
          ..addAll(schedule.activeMonthDays!);
      } else {
        _activeWeekdays
          ..clear()
          ..addAll(schedule.activeWeekdays);
      }
    } else if (schedule is HabitSchedule) {
      _activeWeekdays
        ..clear()
        ..addAll(schedule.activeWeekdays);
      _targetController.text = schedule.targetCount.toString();
      _habitPeriod = schedule.period;
    }

    _reminders.addAll(task.reminders);

    final counters = task.habitCounters;
    if (counters != null) {
      _positiveCounterEnabled = counters.positiveEnabled;
      _negativeCounterEnabled = counters.negativeEnabled;
    }
    if (task.type == TaskType.habit) {
      final todayEntry = task.historyEntryOn(DateTime.now());
      _positiveCountController.text = (todayEntry?.positiveCount ?? 0)
          .toString();
      _negativeCountController.text = (todayEntry?.negativeCount ?? 0)
          .toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _targetController.dispose();
    _positiveCountController.dispose();
    _negativeCountController.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (time != null && mounted) setState(() => _reminderTime = time);
  }

  void _adjustReminderTime(int minutes) {
    const minutesPerDay = Duration.hoursPerDay * Duration.minutesPerHour;
    final currentMinutes =
        _reminderTime.hour * Duration.minutesPerHour + _reminderTime.minute;
    final adjustedMinutes = (currentMinutes + minutes) % minutesPerDay;
    setState(() {
      _reminderTime = TimeOfDay(
        hour: adjustedMinutes ~/ Duration.minutesPerHour,
        minute: adjustedMinutes % Duration.minutesPerHour,
      );
    });
  }

  Future<void> _openHistory() async {
    final task = widget.task;
    if (task == null) return;
    final today = DateTime.now();
    final before = task.historyEntryOn(today);
    final previousCounts = (
      before?.positiveCount ?? 0,
      before?.negativeCount ?? 0,
    );
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskHistoryPage(
          task: task,
          settings: widget.settings,
          onSave: widget.onHistoryChanged,
        ),
      ),
    );
    if (!mounted) return;
    final after = task.historyEntryOn(today);
    if (previousCounts !=
        (after?.positiveCount ?? 0, after?.negativeCount ?? 0)) {
      _positiveCountController.text = '${after?.positiveCount ?? 0}';
      _negativeCountController.text = '${after?.negativeCount ?? 0}';
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text(
          'The task and its entire history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onDelete?.call();
    Navigator.pop(context);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final activeDays = _isMonthlyDaily ? _activeMonthDays : _activeWeekdays;
    if (widget.taskType != TaskType.todo && activeDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one active day.')),
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
      TaskType.todo => const TodoSchedule(),
      TaskType.daily =>
        _dailyMonthly
            ? DailySchedule.monthly(activeMonthDays: Set.of(_activeMonthDays))
            : DailySchedule(activeWeekdays: Set.of(_activeWeekdays)),
      TaskType.habit => HabitSchedule(
        activeWeekdays: Set.of(_activeWeekdays),
        targetCount: int.parse(_targetController.text),
        period: _habitPeriod,
      ),
    };

    final editedTask = widget.task;
    final savedTask = Task(
      id: editedTask?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: widget.taskType,
      title: _titleController.text.trim(),
      notes: _notesController.text.trim(),
      tagIds: _tagIds.intersection(
        widget.settings.tags.map((tag) => tag.id).toSet(),
      ),
      schedule: schedule,
      habitCounters: widget.taskType == TaskType.habit
          ? HabitCounters(
              positiveEnabled: _positiveCounterEnabled,
              negativeEnabled: _negativeCounterEnabled,
            )
          : null,
      reminders: _reminders,
      isCompleted: editedTask?.isCompleted ?? false,
      completedAt: editedTask?.completedAt,
      lastCompletedDate: editedTask?.lastCompletedDate,
      positiveCount: editedTask?.positiveCount ?? 0,
      negativeCount: editedTask?.negativeCount ?? 0,
      createdAt: editedTask?.createdAt,
      history: editedTask?.history,
    );
    if (_isEditing && widget.taskType == TaskType.habit) {
      savedTask.setHabitPointsForDate(
        DateTime.now(),
        positive: int.parse(_positiveCountController.text),
        negative: int.parse(_negativeCountController.text),
      );
    }
    Navigator.pop(context, savedTask);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_isEditing ? 'Edit' : 'New'} $_typeName'),
        actions: [
          if (_isEditing && widget.taskType != TaskType.todo)
            IconButton(
              tooltip: 'History',
              onPressed: _openHistory,
              icon: const Icon(Icons.show_chart),
            ),
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
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
            Text('Tags', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TaskTagPicker(
              settings: widget.settings,
              selected: _tagIds,
              onChanged: (selected) => setState(() => _tagIds = selected),
            ),
            if (widget.taskType != TaskType.todo) ...[
              const SizedBox(height: 24),
              Text('Scheduling', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
            ],
            if (widget.taskType == TaskType.daily) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Weekly')),
                  ButtonSegment(value: true, label: Text('Monthly')),
                ],
                selected: {_dailyMonthly},
                onSelectionChanged: (selection) =>
                    setState(() => _dailyMonthly = selection.first),
              ),
              const SizedBox(height: 12),
            ],
            if (_isMonthlyDaily) ...[
              const Text('Active days of the month'),
              const SizedBox(height: 8),
              _buildMonthDayPicker(selectedDays: _activeMonthDays),
              const SizedBox(height: 8),
              const Text(
                'Days 29-31 are skipped in months that do not have them.',
              ),
            ] else if (widget.taskType != TaskType.todo)
              _buildWeekdaySchedule(),
            if (widget.taskType == TaskType.habit) ...[
              _buildHabitGoal(),
              const SizedBox(height: 16),
              _buildHabitCounters(),
            ],
            const SizedBox(height: 24),
            _buildReminders(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminderDate() async {
    final date = await showDatePicker(
      context: context,
      locale: widget.settings.firstDayOfWeek == FirstDayOfWeek.monday
          ? const Locale('en', 'GB')
          : const Locale('en', 'US'),
      initialDate: _reminderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null && mounted) setState(() => _reminderDate = date);
  }

  void _editReminder(TaskReminder reminder) {
    setState(() {
      _editingReminderId = reminder.id;
      _reminderTime = TimeOfDay(
        hour: reminder.time.hour,
        minute: reminder.time.minute,
      );
      _reminderDate = reminder.date ?? Task.dateOnly(DateTime.now());
      _untilCompleted = reminder.untilCompleted;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final editorContext = _reminderEditorKey.currentContext;
      if (mounted && editorContext != null) {
        Scrollable.ensureVisible(
          editorContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  void _resetReminderEditor() {
    _editingReminderId = null;
    _reminderTime = widget.settings.defaultReminderTimeAt(DateTime.now());
    _reminderDate = Task.dateOnly(DateTime.now());
    _untilCompleted = false;
  }

  void _addOrUpdateReminder() {
    final isTodo = widget.taskType == TaskType.todo;
    final untilCompleted = isTodo && _untilCompleted;
    final date = isTodo && !untilCompleted ? _reminderDate : null;
    if (isTodo && !untilCompleted) {
      final scheduled = DateTime(
        date!.year,
        date.month,
        date.day,
        _reminderTime.hour,
        _reminderTime.minute,
      );
      if (!scheduled.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a future reminder date and time.'),
          ),
        );
        return;
      }
    }
    if (_reminders.any(
      (reminder) =>
          reminder.id != _editingReminderId &&
          reminder.untilCompleted == untilCompleted &&
          reminder.time.hour == _reminderTime.hour &&
          reminder.time.minute == _reminderTime.minute &&
          (reminder.date == null
              ? date == null
              : date != null && Task.dateOnly(reminder.date!) == date),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A reminder is already set for this time.'),
        ),
      );
      return;
    }
    final reminder = TaskReminder(
      id:
          _editingReminderId ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      time: ReminderTime(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      ),
      date: date,
      untilCompleted: untilCompleted,
    );
    setState(() {
      final index = _reminders.indexWhere((item) => item.id == reminder.id);
      if (index < 0) {
        _reminders.add(reminder);
      } else {
        _reminders[index] = reminder;
      }
      _reminders.sort((a, b) {
        final dates = (a.date ?? DateTime(2000)).compareTo(
          b.date ?? DateTime(2000),
        );
        return dates != 0
            ? dates
            : (a.time.hour * 60 + a.time.minute).compareTo(
                b.time.hour * 60 + b.time.minute,
              );
      });
      // Keep the chosen time/date ready for the next quick adjustment.
      _editingReminderId = null;
    });
  }

  Widget _buildReminders() {
    final colors = Theme.of(context).colorScheme;
    final editing = _editingReminderId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Reminders', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (!widget.settings.notificationsEnabled) ...[
          const Text('Notifications are disabled in Settings.'),
          const SizedBox(height: 8),
        ],
        if (_reminders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No reminders set'),
          ),
        for (final reminder in _reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: ValueKey('reminder-${reminder.id}'),
              tileColor: colors.surfaceContainer,
              selectedTileColor: colors.primaryContainer,
              selected: reminder.id == _editingReminderId,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.notifications_outlined),
              title: Text(
                TimeOfDay(
                  hour: reminder.time.hour,
                  minute: reminder.time.minute,
                ).format(context),
              ),
              subtitle: reminder.untilCompleted
                  ? const Text('Until completed')
                  : reminder.date == null
                  ? null
                  : Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(reminder.date!),
                    ),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: () => _editReminder(reminder),
            ),
          ),
        if (widget.taskType != TaskType.todo) ...[
          const Text("Reminders repeat on the task's active days."),
          const SizedBox(height: 12),
        ],
        Column(
          key: _reminderEditorKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editing ? 'Edit reminder' : 'Time'),
            const SizedBox(height: 8),
            _buildReminderTimeControls(),
            if (widget.taskType == TaskType.todo)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Until completed'),
                subtitle: const Text(
                  'Reminds every day until the task is completed',
                ),
                value: _untilCompleted,
                onChanged: (value) =>
                    setState(() => _untilCompleted = value ?? false),
              ),
            if (widget.taskType == TaskType.todo)
              ListTile(
                enabled: !_untilCompleted,
                contentPadding: EdgeInsets.zero,
                leading: const SizedBox(
                  width: 40,
                  child: Center(child: Icon(Icons.event_outlined)),
                ),
                title: const Text('Reminder date'),
                trailing: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(_reminderDate),
                ),
                onTap: _untilCompleted ? null : _pickReminderDate,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (editing) ...[
                  IconButton(
                    tooltip: 'Delete reminder',
                    color: colors.error,
                    onPressed: () => setState(() {
                      _reminders.removeWhere(
                        (reminder) => reminder.id == _editingReminderId,
                      );
                      _resetReminderEditor();
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  TextButton(
                    onPressed: () => setState(_resetReminderEditor),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addOrUpdateReminder,
                    icon: Icon(editing ? Icons.check : Icons.add),
                    label: Text(editing ? 'Save reminder' : 'Add reminder'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildReminderTimeControls() {
    return Row(
      children: [
        _buildTimeAdjustmentButton('-1h', -60),
        const SizedBox(width: 4),
        _buildTimeAdjustmentButton('-15min', -15),
        const SizedBox(width: 4),
        Expanded(
          flex: 2,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onPressed: _pickReminderTime,
            child: Text(_reminderTime.format(context)),
          ),
        ),
        const SizedBox(width: 4),
        _buildTimeAdjustmentButton('+15min', 15),
        const SizedBox(width: 4),
        _buildTimeAdjustmentButton('+1h', 60),
      ],
    );
  }

  Widget _buildTimeAdjustmentButton(String label, int minutes) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: () => _adjustReminderTime(minutes),
        child: Text(label, maxLines: 1),
      ),
    );
  }

  Widget _buildWeekdaySchedule() {
    return _buildWeekdayPicker(selectedWeekdays: _activeWeekdays);
  }

  Widget _buildMonthDayPicker({
    required Set<int> selectedDays,
    Set<int>? allowedDays,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        5,
        (row) => Padding(
          padding: EdgeInsets.only(top: row == 0 ? 0 : 6),
          child: Row(
            children: List.generate(7, (column) {
              final day = row * 7 + column + 1;
              if (day > 31) return const Expanded(child: SizedBox());
              final enabled = allowedDays?.contains(day) ?? true;
              final selected = enabled && selectedDays.contains(day);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: column == 0 ? 0 : 4),
                  child: Semantics(
                    label: 'Day $day',
                    selected: selected,
                    enabled: enabled,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: !enabled
                          ? null
                          : () => setState(() {
                              if (!selectedDays.add(day)) {
                                selectedDays.remove(day);
                              }
                            }),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primaryContainer
                              : Colors.transparent,
                          border: Border.all(
                            color: enabled
                                ? colors.outline
                                : colors.outline.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: enabled
                                ? null
                                : colors.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayPicker({
    required Set<int> selectedWeekdays,
    Set<int>? allowedWeekdays,
  }) {
    const labels = {
      DateTime.monday: 'M',
      DateTime.tuesday: 'T',
      DateTime.wednesday: 'W',
      DateTime.thursday: 'T',
      DateTime.friday: 'F',
      DateTime.saturday: 'S',
      DateTime.sunday: 'S',
    };
    final weekdays = widget.settings.firstDayOfWeek == FirstDayOfWeek.monday
        ? const [1, 2, 3, 4, 5, 6, 7]
        : const [7, 1, 2, 3, 4, 5, 6];
    return Row(
      children: List.generate(weekdays.length, (index) {
        final weekday = weekdays[index];
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
                  labels[weekday]!,
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
        if (_isEditing) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _positiveCountController,
                  enabled: _positiveCounterEnabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Today's positive",
                    prefixIcon: Icon(Icons.add),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      _validateCounter(value, enabled: _positiveCounterEnabled),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _negativeCountController,
                  enabled: _negativeCounterEnabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Today's negative",
                    prefixIcon: Icon(Icons.remove),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      _validateCounter(value, enabled: _negativeCounterEnabled),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String? _validateCounter(String? value, {required bool enabled}) {
    if (!enabled) return null;
    final count = int.tryParse(value ?? '');
    return count == null || count < 0 ? 'Enter 0 or more.' : null;
  }
}
