import 'dart:convert';

import '../../utils/request_user_input.dart';

/// Formats a resolved AskUserQuestion request as a readable chat entry.
///
/// [result] may be a direct answer for a single question or a structured
/// envelope containing answers keyed by question ID or question text.
String? questionAnswerTranscriptText({
  required Map<String, dynamic>? input,
  required String result,
}) {
  final envelope = _answerEnvelope(result);
  final inputQuestions = _questions(input?['questions']);
  final questions = inputQuestions.isNotEmpty
      ? inputQuestions
      : _questions(envelope?['questions']);
  if (questions.isEmpty) return null;
  if (envelope == null && result.trim().toLowerCase() == 'answered') {
    return null;
  }

  final answers = envelope?['answers'];
  final answerMap = answers is Map
      ? Map<String, dynamic>.from(answers)
      : const <String, dynamic>{};
  final blocks = <String>[];

  for (final question in questions) {
    final text = question['question'] as String?;
    if (text == null || text.trim().isEmpty) continue;

    final id = question['id'] as String?;
    final Object? answer =
        (id == null ? null : answerMap[id]) ??
        answerMap[text] ??
        (envelope == null && questions.length == 1 ? result : null);
    final answerText = _answerText(answer);
    if (answerText == null) continue;

    blocks.add('Question: ${text.trim()}\nAnswer: $answerText');
  }

  if (blocks.isEmpty) return null;
  return blocks.join('\n\n');
}

Map<String, dynamic>? _answerEnvelope(String result) {
  try {
    final decoded = jsonDecode(result);
    if (decoded is! Map) return null;
    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['answers'] is! Map) return null;
    return envelope;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

List<Map<String, dynamic>> _questions(Object? raw) {
  return requestUserInputQuestions({'questions': raw});
}

String? _answerText(Object? answer) {
  if (answer == null) return null;
  if (answer is List) {
    final values = answer
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? null : values.join(', ');
  }
  final value = answer.toString().trim();
  return value.isEmpty ? null : value;
}
