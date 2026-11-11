import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/themes/default_theme.dart';
import 'package:taskforge/services/task_storage.dart';

class TaskHistoryPage extends StatefulWidget {
  const TaskHistoryPage({
    required this.task,
    required this.settings,
    this.onSave,
    super.key,
  });

  final Task task;
  final AppSettings settings;
  final Future<void> Function(Task)? onSave;

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage> {
  Task get task => widget.task;
  AppSettings get settings => widget.settings;
  bool _saving = false;

  Future<void> _editDay(_HistoryDay day) async {
    if (_saving) return;
    final formKey = GlobalKey<FormState>();
    var positive = day.positiveCount;
    var negative = day.negativeCount;
    var completed = day.dailyCompleted;
    final result =
        await showDialog<({int positive, int negative, bool completed})>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              title: Text(
                MaterialLocalizations.of(context).formatMediumDate(day.date),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.type == TaskType.daily)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(completed ? 'Done' : 'Skipped'),
                        value: completed,
                        onChanged: (value) => update(() => completed = value),
                      )
                    else ...[
                      TextFormField(
                        initialValue: '$positive',
                        keyboardType: TextInputType.number,
                        enabled: task.habitCounters?.positiveEnabled ?? true,
                        decoration: const InputDecoration(
                          labelText: 'Positive',
                        ),
                        validator: _validateCount,
                        onChanged: (value) =>
                            positive = int.tryParse(value) ?? -1,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: '$negative',
                        keyboardType: TextInputType.number,
                        enabled: task.habitCounters?.negativeEnabled ?? true,
                        decoration: const InputDecoration(
                          labelText: 'Negative',
                        ),
                        validator: _validateCount,
                        onChanged: (value) =>
                            negative = int.tryParse(value) ?? -1,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context, (
                        positive: positive,
                        negative: negative,
                        completed: completed,
                      ));
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
    if (result == null || !mounted) return;
    final updated = Task.fromJson(task.toJson());
    if (task.type == TaskType.daily) {
      updated.setCompletedOn(day.date, completed: result.completed);
    } else {
      updated.setHabitPointsForDate(
        day.date,
        positive: result.positive,
        negative: result.negative,
      );
    }
    setState(() => _saving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(updated);
      } else {
        await (await TaskStorage.open()).saveTask(updated);
      }
      task.history
        ..clear()
        ..addAll(updated.history);
      task.positiveCount = updated.positiveCount;
      task.negativeCount = updated.negativeCount;
      task.lastCompletedDate = updated.lastCompletedDate;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History changes could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateCount(String? value) {
    final count = int.tryParse(value ?? '');
    return count == null || count < 0 ? 'Enter 0 or more.' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final allDays = _buildHistoryDays();
        final hideEmpty =
            task.type == TaskType.habit && settings.hideEmptyHabitHistory;
        final days = hideEmpty
            ? allDays
                  .where(
                    (day) => day.positiveCount != 0 || day.negativeCount != 0,
                  )
                  .toList()
            : allDays;

        return Scaffold(
          appBar: AppBar(title: Text('${task.title} history')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (task.type == TaskType.habit) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Hide empty records'),
                  subtitle: const Text('Hide days with +0 | -0'),
                  value: settings.hideEmptyHabitHistory,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setHideEmptyHabitHistory(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (days.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 72),
                  child: Text(
                    hideEmpty
                        ? 'No non-empty habit records yet.'
                        : 'No history yet.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                _HistoryChart(task: task, days: days),
                const SizedBox(height: 24),
                Text(
                  'Daily summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...days.reversed.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryListTile(
                      task: task,
                      day: day,
                      onLongPress: _saving ? null : () => _editDay(day),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<_HistoryDay> _buildHistoryDays() {
    final result = <_HistoryDay>[];
    final today = Task.dateOnly(DateTime.now());
    var date = Task.dateOnly(task.createdAt);

    while (!date.isAfter(today)) {
      final entry = task.historyEntryOn(date);
      final isExtraDailyCompletion =
          task.type == TaskType.daily && (entry?.dailyCompleted ?? false);
      if (task.isScheduledOn(date) || isExtraDailyCompletion) {
        final isToday = date == today;
        if (!isToday || entry != null) {
          result.add(
            _HistoryDay(
              date: date,
              positiveCount: entry?.positiveCount ?? 0,
              negativeCount: entry?.negativeCount ?? 0,
              dailyCompleted: entry?.dailyCompleted ?? false,
            ),
          );
        }
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
    return result;
  }
}

class _HistoryDay {
  const _HistoryDay({
    required this.date,
    required this.positiveCount,
    required this.negativeCount,
    required this.dailyCompleted,
  });

  final DateTime date;
  final int positiveCount;
  final int negativeCount;
  final bool dailyCompleted;
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.task, required this.days});

  final Task task;
  final List<_HistoryDay> days;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final counters = task.habitCounters;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(
              painter: _HistoryChartPainter(
                days: days,
                isDaily: task.type == TaskType.daily,
                positiveEnabled: counters?.positiveEnabled ?? true,
                negativeEnabled: counters?.negativeEnabled ?? true,
                gridColor: colors.outlineVariant,
                labelColor: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: task.type == TaskType.daily
                ? [_ChartLegend(color: DefaultTheme.yellow, label: 'Done')]
                : [
                    if (counters?.positiveEnabled ?? true)
                      _ChartLegend(
                        color: DefaultTheme.green,
                        label: 'Positive',
                      ),
                    if (counters?.negativeEnabled ?? true)
                      _ChartLegend(color: DefaultTheme.red, label: 'Negative'),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  const _HistoryChartPainter({
    required this.days,
    required this.isDaily,
    required this.positiveEnabled,
    required this.negativeEnabled,
    required this.gridColor,
    required this.labelColor,
  });

  final List<_HistoryDay> days;
  final bool isDaily;
  final bool positiveEnabled;
  final bool negativeEnabled;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const top = 12.0;
    const right = 8.0;
    const bottom = 28.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final maxValue = _maxValue();

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = top + chartHeight * index / 4;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
    }

    _paintLabel(canvas, maxValue.toString(), const Offset(0, top - 7));
    _paintLabel(canvas, '0', Offset(12, top + chartHeight - 7));
    _paintDateLabels(canvas, left, top + chartHeight + 7, chartWidth);

    if (isDaily) {
      _drawSeries(
        canvas,
        size,
        days.map((day) => day.dailyCompleted ? 1 : 0).toList(),
        DefaultTheme.yellow,
        maxValue,
      );
      return;
    }
    if (positiveEnabled) {
      _drawSeries(
        canvas,
        size,
        days.map((day) => day.positiveCount).toList(),
        DefaultTheme.green,
        maxValue,
      );
    }
    if (negativeEnabled) {
      _drawSeries(
        canvas,
        size,
        days.map((day) => day.negativeCount).toList(),
        DefaultTheme.red,
        maxValue,
      );
    }
  }

  int _maxValue() {
    if (isDaily) return 1;
    var maximum = 1;
    for (final day in days) {
      if (positiveEnabled) maximum = math.max(maximum, day.positiveCount);
      if (negativeEnabled) maximum = math.max(maximum, day.negativeCount);
    }
    return maximum;
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<int> values,
    Color color,
    int maxValue,
  ) {
    const left = 30.0;
    const top = 12.0;
    const right = 8.0;
    const bottom = 28.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? left + width / 2
          : left + width * index / (values.length - 1);
      final y = top + height * (1 - values[index] / maxValue);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, pointPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  void _paintDateLabels(Canvas canvas, double left, double y, double width) {
    final first = days.first.date;
    final last = days.last.date;
    _paintLabel(canvas, '${first.day}/${first.month}', Offset(left, y));
    if (days.length > 1) {
      final label = '${last.day}/${last.month}';
      final painter = _textPainter(label);
      painter.paint(canvas, Offset(left + width - painter.width, y));
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset offset) {
    _textPainter(text).paint(canvas, offset);
  }

  TextPainter _textPainter(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: labelColor, fontSize: 11),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.isDaily != isDaily ||
      oldDelegate.positiveEnabled != positiveEnabled ||
      oldDelegate.negativeEnabled != negativeEnabled ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}

class _HistoryListTile extends StatelessWidget {
  const _HistoryListTile({
    required this.task,
    required this.day,
    this.onLongPress,
  });
  final VoidCallback? onLongPress;

  final Task task;
  final _HistoryDay day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onLongPress: onLongPress,
      tileColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(MaterialLocalizations.of(context).formatMediumDate(day.date)),
      trailing: task.type == TaskType.daily
          ? Text(
              day.dailyCompleted ? 'Done' : 'Skipped',
              style: TextStyle(
                color: day.dailyCompleted
                    ? DefaultTheme.green
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          : _HabitHistoryValue(task: task, day: day),
    );
  }
}

class _HabitHistoryValue extends StatelessWidget {
  const _HabitHistoryValue({required this.task, required this.day});

  final Task task;
  final _HistoryDay day;

  @override
  Widget build(BuildContext context) {
    final counters = task.habitCounters;
    final positiveEnabled = counters?.positiveEnabled ?? true;
    final negativeEnabled = counters?.negativeEnabled ?? true;

    return Text.rich(
      TextSpan(
        children: [
          if (positiveEnabled)
            TextSpan(
              text: '+${day.positiveCount}',
              style: TextStyle(color: DefaultTheme.green),
            ),
          if (positiveEnabled && negativeEnabled) const TextSpan(text: '  |  '),
          if (negativeEnabled)
            TextSpan(
              text: '-${day.negativeCount}',
              style: TextStyle(color: DefaultTheme.red),
            ),
        ],
      ),
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
