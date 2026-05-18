// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class PerformanceAdapter extends TypeAdapter<Performance> {
  @override
  final typeId = 1;

  @override
  Performance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Performance(
      id: fields[7] as String,
      score: fields[0] as String,
      studentName: fields[1] as String,
      subject: fields[2] as String,
      topic: fields[3] as String,
      timeTaken: fields[4] as String,
      mistakesMade: fields[5] as String,
      summaryFeedback: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Performance obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.score)
      ..writeByte(1)
      ..write(obj.studentName)
      ..writeByte(2)
      ..write(obj.subject)
      ..writeByte(3)
      ..write(obj.topic)
      ..writeByte(4)
      ..write(obj.timeTaken)
      ..writeByte(5)
      ..write(obj.mistakesMade)
      ..writeByte(6)
      ..write(obj.summaryFeedback)
      ..writeByte(7)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerformanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final typeId = 2;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      name: fields[0] as String,
      classLevel: fields[1] as String,
      language: fields[2] as String,
      subjects: (fields[3] as List).cast<String>(),
      disability: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.classLevel)
      ..writeByte(2)
      ..write(obj.language)
      ..writeByte(3)
      ..write(obj.subjects)
      ..writeByte(4)
      ..write(obj.disability);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubjectAdapter extends TypeAdapter<Subject> {
  @override
  final typeId = 3;

  @override
  Subject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subject(
      name: fields[0] as String,
      chapters: (fields[1] as List).cast<Chapters>(),
    );
  }

  @override
  void write(BinaryWriter writer, Subject obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.chapters);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChaptersAdapter extends TypeAdapter<Chapters> {
  @override
  final typeId = 4;

  @override
  Chapters read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chapters(subtopics: (fields[0] as List).cast<Subtopics>());
  }

  @override
  void write(BinaryWriter writer, Chapters obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.subtopics);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChaptersAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubtopicsAdapter extends TypeAdapter<Subtopics> {
  @override
  final typeId = 5;

  @override
  Subtopics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subtopics(text: fields[0] as String?);
  }

  @override
  void write(BinaryWriter writer, Subtopics obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.text);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtopicsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubjectGeneratedTextAdapter extends TypeAdapter<SubjectGeneratedText> {
  @override
  final typeId = 6;

  @override
  SubjectGeneratedText read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubjectGeneratedText(
      id: fields[0] as String,
      generatedText: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SubjectGeneratedText obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.generatedText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectGeneratedTextAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
