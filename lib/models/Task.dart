import 'CheckElement.dart';

class Task{

  String title;
  String note;
  bool isCompleted;
  List<CheckElement> checkList = List.empty(growable: true);

  Task({
    required this.title,
    required this.note,
    required this.isCompleted,
  });

}