import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskforge/models/task.dart';

class TaskStorage {
  TaskStorage._(this.rootDirectory);

  @visibleForTesting
  TaskStorage.forDirectory(this.rootDirectory);

  final Directory rootDirectory;
  final Map<String, Future<void>> _pendingWrites = {};

  static Future<TaskStorage> open() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final storage = TaskStorage._(
      Directory('${documentsDirectory.path}${Platform.pathSeparator}taskforge'),
    );
    await storage._createDirectories();
    return storage;
  }

  Future<Map<TaskType, List<Task>>> loadAll() async {
    final tasks = {
      TaskType.habit: await _loadDirectory(TaskType.habit),
      TaskType.daily: await _loadDirectory(TaskType.daily),
      TaskType.todo: await _loadDirectory(TaskType.todo),
    };
    for (final taskList in tasks.values) {
      taskList.sort(
        (first, second) => first.createdAt.compareTo(second.createdAt),
      );
    }
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    for (final task in tasks.values.expand((taskList) => taskList)) {
      if (task.backfillHistoryThrough(yesterday)) await saveTask(task);
    }
    return tasks;
  }

  Future<void> saveTask(Task task) {
    final previousWrite = _pendingWrites[task.id] ?? Future<void>.value();
    final write = () async {
      try {
        await previousWrite;
      } on Object {
        // A later change should still be saved after an earlier failed write.
      }
      await _writeTask(task);
    }();
    _pendingWrites[task.id] = write;
    return write.whenComplete(() {
      if (identical(_pendingWrites[task.id], write)) {
        _pendingWrites.remove(task.id);
      }
    });
  }

  Future<void> _writeTask(Task task) async {
    final directory = _directoryFor(task.type);
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_safeId(task.id)}.json',
    );
    await file.writeAsString(jsonEncode(task.toJson()), flush: true);
  }

  Future<void> deleteTask(Task task) async {
    final pendingWrite = _pendingWrites[task.id];
    if (pendingWrite != null) {
      try {
        await pendingWrite;
      } on Object {
        // Continue with deletion even if the last save failed.
      }
    }
    final file = File(
      '${_directoryFor(task.type).path}'
      '${Platform.pathSeparator}${_safeId(task.id)}.json',
    );
    if (await file.exists()) await file.delete();
  }

  Future<List<Task>> _loadDirectory(TaskType type) async {
    final result = <Task>[];
    final directory = _directoryFor(type);
    await directory.create(recursive: true);
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map) continue;
        final task = Task.fromJson(Map<String, dynamic>.from(decoded));
        if (task.type == type) result.add(task);
      } on Object {
        // Ignore a damaged task file so the remaining tasks can still load.
      }
    }
    return result;
  }

  Future<void> _createDirectories() async {
    await rootDirectory.create(recursive: true);
    for (final type in TaskType.values) {
      await _directoryFor(type).create(recursive: true);
    }
  }

  Directory _directoryFor(TaskType type) {
    final folderName = switch (type) {
      TaskType.habit => 'habits',
      TaskType.daily => 'daily',
      TaskType.todo => 'tasks',
    };
    return Directory(
      '${rootDirectory.path}${Platform.pathSeparator}$folderName',
    );
  }

  String _safeId(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}
