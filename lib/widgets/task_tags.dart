import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/models/task_tag.dart';

Future<TaskTag?> showTagEditor(
  BuildContext context,
  AppSettings settings, {
  TaskTag? tag,
}) => showDialog<TaskTag>(
  context: context,
  builder: (_) => _TagEditor(settings: settings, tag: tag),
);

class _TagEditor extends StatefulWidget {
  const _TagEditor({required this.settings, this.tag});

  final AppSettings settings;
  final TaskTag? tag;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _hex;
  late int _color;
  bool _saving = false;
  String? _error;

  static const _palette = [
    0xFF9D44E3,
    0xFF7E57C2,
    0xFF536DFE,
    0xFF42A5F5,
    0xFF26C6DA,
    0xFF26A69A,
    0xFF25CD90,
    0xFF9CCC65,
    0xFFFEBE5C,
    0xFFFF8A65,
    0xFFFF5353,
    0xFFEC407A,
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.tag?.name ?? '');
    _color = widget.tag?.color ?? _palette.first;
    _hex = TextEditingController(text: _hexText(_color));
  }

  String _hexText(int color) =>
      (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final tag = TaskTag(
      id: widget.tag?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      color: _color,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.settings.saveTag(tag);
      if (mounted) Navigator.pop(context, tag);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The tag could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete tag?'),
        content: Text(
          'Remove "${widget.tag!.name}" from all tasks? Your tasks and their history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.settings.deleteTag(widget.tag!.id);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The tag could not be deleted. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.tag == null ? 'New tag' : 'Edit tag'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a tag name.'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text('Color'),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    for (final color in _palette)
                      Semantics(
                        label: 'Color #${_hexText(color)}',
                        selected: _color == color,
                        button: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _saving
                              ? null
                              : () => setState(() {
                                  _color = color;
                                  _hex.text = _hexText(color);
                                }),
                          child: Ink(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                            ),
                            child: _color == color
                                ? Icon(
                                    Icons.check,
                                    color:
                                        ThemeData.estimateBrightnessForColor(
                                              Color(color),
                                            ) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hex,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'Custom color',
                    prefixText: '#',
                    border: const OutlineInputBorder(),
                    suffixIcon: Icon(Icons.circle, color: Color(_color)),
                  ),
                  validator: (value) =>
                      RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter 6 hexadecimal digits.',
                  onChanged: (value) {
                    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value.trim())) {
                      setState(
                        () => _color =
                            0xFF000000 | int.parse(value.trim(), radix: 16),
                      );
                    }
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.tag != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _saving ? null : _delete,
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

class TagTile extends StatelessWidget {
  const TagTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.onLongPress,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? colors.primary : colors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (color != null) ...[
                  Icon(Icons.circle, size: 14, color: color),
                  const SizedBox(width: 8),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskTagList extends StatefulWidget {
  const TaskTagList({
    required this.settings,
    required this.tasks,
    required this.builder,
    super.key,
  });

  final AppSettings settings;
  final List<Task> tasks;
  final Widget Function(List<Task> tasks) builder;

  @override
  State<TaskTagList> createState() => _TaskTagListState();
}

class _TaskTagListState extends State<TaskTagList> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.settings,
    builder: (context, _) {
      final tags = widget.settings.tags;
      _selected.retainAll(tags.map((tag) => tag.id));
      final filtered = _selected.isEmpty
          ? widget.tasks
          : widget.tasks
                .where((task) => task.tagIds.any(_selected.contains))
                .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                TagTile(
                  label: 'All',
                  selected: _selected.isEmpty,
                  onTap: () => setState(_selected.clear),
                ),
                for (final tag in tags) ...[
                  const SizedBox(width: 8),
                  TagTile(
                    label: tag.name,
                    color: Color(tag.color),
                    selected: _selected.contains(tag.id),
                    onTap: () => setState(() {
                      if (!_selected.add(tag.id)) _selected.remove(tag.id);
                    }),
                    onLongPress: () =>
                        showTagEditor(context, widget.settings, tag: tag),
                  ),
                ],
                if (widget.settings.tagAddButtonVisibility.onLists) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Add tag',
                    child: TagTile(
                      label: '+',
                      selected: false,
                      onTap: () => showTagEditor(context, widget.settings),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty && _selected.isNotEmpty
                ? const Center(child: Text('No tasks match the selected tags.'))
                : widget.builder(filtered),
          ),
        ],
      );
    },
  );
}

/// Decorates only the task's content area, leaving its controls unchanged.
class TaskTagContent extends StatelessWidget {
  const TaskTagContent({
    required this.settings,
    required this.task,
    required this.child,
    super.key,
  });

  final AppSettings settings;
  final Task task;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) {
      final tags = settings.showTagColorBars
          ? settings.tags.where((tag) => task.tagIds.contains(tag.id)).toList()
          : <TaskTag>[];
      if (tags.isEmpty) return child;
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: settings.tagColorBarHeight.toDouble(),
                child: Row(
                  children: [
                    for (final tag in tags)
                      Expanded(
                        child: ColoredBox(
                          color: Color(tag.color),
                          child: SizedBox(
                            height: settings.tagColorBarHeight.toDouble(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class TaskTagPicker extends StatelessWidget {
  const TaskTagPicker({
    required this.settings,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AppSettings settings;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in settings.tags)
          TagTile(
            label: tag.name,
            color: Color(tag.color),
            selected: selected.contains(tag.id),
            onTap: () {
              final updated = Set<String>.of(selected);
              if (!updated.add(tag.id)) updated.remove(tag.id);
              onChanged(updated);
            },
          ),
        if (settings.tagAddButtonVisibility.onTasks)
          Tooltip(
            message: 'Add tag',
            child: TagTile(
              label: '+',
              selected: false,
              onTap: () async {
                final tag = await showTagEditor(context, settings);
                if (tag != null && context.mounted) {
                  onChanged({...selected, tag.id});
                }
              },
            ),
          ),
        if (settings.tags.isEmpty && !settings.tagAddButtonVisibility.onTasks)
          const Text('No tags available.'),
      ],
    ),
  );
}
