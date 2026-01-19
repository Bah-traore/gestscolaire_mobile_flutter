import 'package:json_annotation/json_annotation.dart';

part 'timetable_models.g.dart';

@JsonSerializable()
class EleveLite {
  final int id;
  final String? nom;
  final String? prenom;
  final String? classe;

  EleveLite({required this.id, this.nom, this.prenom, this.classe});

  String get fullName {
    final n = (nom ?? '').trim();
    final p = (prenom ?? '').trim();
    return [n, p].where((e) => e.isNotEmpty).join(' ');
  }

  factory EleveLite.fromJson(Map<String, dynamic> json) =>
      _$EleveLiteFromJson(json);
  Map<String, dynamic> toJson() => _$EleveLiteToJson(this);
}

@JsonSerializable()
class TimetableEvent {
  final int id;
  final String title;
  final String start;
  final String end;
  final String? matiere;
  @JsonKey(name: 'matiere_id')
  final int? matiereId;
  final String? enseignant;
  @JsonKey(name: 'enseignant_id')
  final int? enseignantId;
  final String? classe;
  final String? room;
  @JsonKey(name: 'is_recurring')
  final bool? isRecurring;
  @JsonKey(name: 'enseignant_absent')
  final bool? enseignantAbsent;
  @JsonKey(name: 'absence_motif')
  final String? absenceMotif;
  @JsonKey(name: 'absence_type')
  final String? absenceType;
  final String? remplacant;

  TimetableEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.matiere,
    this.matiereId,
    this.enseignant,
    this.enseignantId,
    this.classe,
    this.room,
    this.isRecurring,
    this.enseignantAbsent,
    this.absenceMotif,
    this.absenceType,
    this.remplacant,
  });

  factory TimetableEvent.fromJson(Map<String, dynamic> json) =>
      _$TimetableEventFromJson(json);
  Map<String, dynamic> toJson() => _$TimetableEventToJson(this);
}

@JsonSerializable()
class TimetableResponse {
  final bool? success;
  final EleveLite? eleve;
  final Map<String, dynamic>? periode;
  final List<TimetableEvent> events;
  final List<Map<String, dynamic>>? evaluations;
  final List<Map<String, dynamic>>? examens;
  final Map<String, dynamic>? statistics;
  final Map<String, dynamic>? subscription;

  TimetableResponse({
    this.success,
    this.eleve,
    this.periode,
    this.events = const [],
    this.evaluations,
    this.examens,
    this.statistics,
    this.subscription,
  });

  factory TimetableResponse.fromJson(Map<String, dynamic> json) =>
      _$TimetableResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TimetableResponseToJson(this);
}
