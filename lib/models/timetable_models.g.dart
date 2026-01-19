// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EleveLite _$EleveLiteFromJson(Map<String, dynamic> json) => EleveLite(
      id: (json['id'] as num).toInt(),
      nom: json['nom'] as String?,
      prenom: json['prenom'] as String?,
      classe: json['classe'] as String?,
    );

Map<String, dynamic> _$EleveLiteToJson(EleveLite instance) => <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'prenom': instance.prenom,
      'classe': instance.classe,
    };

TimetableEvent _$TimetableEventFromJson(Map<String, dynamic> json) =>
    TimetableEvent(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      start: json['start'] as String,
      end: json['end'] as String,
      matiere: json['matiere'] as String?,
      matiereId: (json['matiere_id'] as num?)?.toInt(),
      enseignant: json['enseignant'] as String?,
      enseignantId: (json['enseignant_id'] as num?)?.toInt(),
      classe: json['classe'] as String?,
      room: json['room'] as String?,
      isRecurring: json['is_recurring'] as bool?,
      enseignantAbsent: json['enseignant_absent'] as bool?,
      absenceMotif: json['absence_motif'] as String?,
      absenceType: json['absence_type'] as String?,
      remplacant: json['remplacant'] as String?,
    );

Map<String, dynamic> _$TimetableEventToJson(TimetableEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'start': instance.start,
      'end': instance.end,
      'matiere': instance.matiere,
      'matiere_id': instance.matiereId,
      'enseignant': instance.enseignant,
      'enseignant_id': instance.enseignantId,
      'classe': instance.classe,
      'room': instance.room,
      'is_recurring': instance.isRecurring,
      'enseignant_absent': instance.enseignantAbsent,
      'absence_motif': instance.absenceMotif,
      'absence_type': instance.absenceType,
      'remplacant': instance.remplacant,
    };

TimetableResponse _$TimetableResponseFromJson(Map<String, dynamic> json) =>
    TimetableResponse(
      success: json['success'] as bool?,
      eleve: json['eleve'] == null
          ? null
          : EleveLite.fromJson(json['eleve'] as Map<String, dynamic>),
      periode: json['periode'] as Map<String, dynamic>?,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => TimetableEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      evaluations: (json['evaluations'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      examens: (json['examens'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      statistics: json['statistics'] as Map<String, dynamic>?,
      subscription: json['subscription'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$TimetableResponseToJson(TimetableResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'eleve': instance.eleve,
      'periode': instance.periode,
      'events': instance.events,
      'evaluations': instance.evaluations,
      'examens': instance.examens,
      'statistics': instance.statistics,
      'subscription': instance.subscription,
    };
