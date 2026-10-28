class TaskTag {
  const TaskTag({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final int color;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory TaskTag.fromJson(Map<String, dynamic> json) => TaskTag(
    id: json['id'] as String,
    name: json['name'] as String,
    color: (json['color'] as num).toInt(),
  );
}

enum TagAddButtonVisibility {
  both,
  listsOnly,
  tasksOnly,
  hidden;

  bool get onLists => this == both || this == listsOnly;
  bool get onTasks => this == both || this == tasksOnly;
}
