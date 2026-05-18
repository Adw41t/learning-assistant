class Performance {
  final String id;
  final String score;
  final String studentName;
  final String subject;
  final String topic;
  final String timeTaken;
  final String mistakesMade;
  final String summaryFeedback;

  Performance({
    required this.id,
    required this.score,
    required this.studentName,
    required this.subject,
    required this.topic,
    required this.timeTaken,
    required this.mistakesMade,
    required this.summaryFeedback,
  });

  factory Performance.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Performance(
        id: "",
        score: "",
        studentName: "",
        subject: "",
        topic: "",
        timeTaken: "",
        mistakesMade: "",
        summaryFeedback: "",
      );
    }
    return Performance(
      id: json['id'],
      score: json['score'],
      studentName: json['studentName'],
      subject: json['subject'],
      topic: json['topic'],
      timeTaken: json['timeTaken'],
      mistakesMade: json['mistakesMade'],
      summaryFeedback: json['summaryFeedback'],
    );
  }
}
