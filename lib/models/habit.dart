class Habit{
  String title;           /// title of the habit
  String note;            /// note of the habit
  bool positiveEnabled;   /// is positive counter button enabled
  bool negativeEnabled;   /// is negative counter button enabled
  int positive;           /// positive counter value
  int negative;           /// negative counter value
  int resetTimer;         /// determines when counters should be reset: daily(1), weekly(2) or monthly(3)
  DateTime lastResetDate; /// when the timer should be reset (every day / week / 1st of the month)

  Habit({
    required this.title,
    required this.note,
    required this.positiveEnabled,
    required this.negativeEnabled,
    required this.positive,
    required this.negative,
    required this.resetTimer,
    required this.lastResetDate,
  });


}