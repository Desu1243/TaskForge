import 'CheckElement.dart';

class DailyTask{
  String title;
  String note;
  bool isCompleted;             /// is this task completed for today
  DateTime lastCompletedDate;   /// when user last completed this task
  int streak;                   /// how many times did user completed this task in a row
  List<CheckElement> checkList = List.empty(growable: true);

  DailyTask({
    required this.title,
    required this.note,
    required this.isCompleted,
    required this.lastCompletedDate,
    required this.streak
  });

}

