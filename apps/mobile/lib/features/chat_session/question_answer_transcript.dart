import 'dart:convert';

import '../../models/messages.dart';
import '../../utils/request_user_input.dart';

/// Reconstructs the resolved question and its selected or typed answers.
QuestionAnswerTranscript? questionAnswerTranscript({
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

  final rawAnswers = envelope?['answers'];
  final answers = rawAnswers is Map
      ? Map<String, dynamic>.from(rawAnswers)
      : const <String, dynamic>{};
  final answeredQuestions = <AnsweredQuestion>[];
  final plainTextBlocks = <String>[];

  for (final question in questions) {
    final questionText = question['question'] as String?;
    if (questionText == null || questionText.trim().isEmpty) continue;

    final id = question['id'] as String?;
    final Object? answer =
        (id == null ? null : answers[id]) ??
        answers[questionText] ??
        (envelope == null && questions.length == 1 ? result : null);
    final answerValues = _answerValues(answer);
    if (answerValues.isEmpty) continue;

    final rawOptions = question['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map((option) {
                return Map<String, dynamic>.from(option);
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final optionLabels = options
        .map((option) => (option['label'] as String? ?? '').trim())
        .toSet();
    final selectedLabels = <String>{};
    final freeTextValues = <String>[];
    var selectedOtherMarker = false;

    for (final value in answerValues) {
      if (optionLabels.contains(value)) {
        selectedLabels.add(value);
        continue;
      }
      final otherAnswer = _otherAnswerValue(value);
      if (otherAnswer == null) {
        selectedOtherMarker = true;
      } else {
        freeTextValues.add(otherAnswer);
      }
    }

    final freeText = freeTextValues.isNotEmpty
        ? freeTextValues.join(', ')
        : selectedOtherMarker
        ? 'Other answer'
        : null;
    if (selectedLabels.isEmpty && freeText == null) continue;

    answeredQuestions.add(
      AnsweredQuestion(
        header: _nonEmpty(question['header'] as String?),
        question: questionText.trim(),
        multiSelect: question['multiSelect'] as bool? ?? false,
        options: [
          for (final option in options)
            if (option['label'] is String)
              AnsweredQuestionOption(
                label: (option['label'] as String).trim(),
                description: _nonEmpty(option['description'] as String?),
                selected: selectedLabels.contains(
                  (option['label'] as String).trim(),
                ),
              ),
        ],
        freeTextAnswer: freeText,
      ),
    );

    final displayedAnswers = <String>[...selectedLabels];
    if (freeText != null) displayedAnswers.add(freeText);
    plainTextBlocks.add(
      'Question: ${questionText.trim()}\nAnswer: ${displayedAnswers.join(', ')}',
    );
  }

  if (answeredQuestions.isEmpty) return null;
  return QuestionAnswerTranscript(
    questions: answeredQuestions,
    plainText: plainTextBlocks.join('\n\n'),
  );
}

/// Plain-text form retained for clipboard, accessibility, and simple callers.
String? questionAnswerTranscriptText({
  required Map<String, dynamic>? input,
  required String result,
}) => questionAnswerTranscript(input: input, result: result)?.plainText;

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

List<String> _answerValues(Object? answer) {
  if (answer == null) return const [];
  if (answer is String) {
    final value = _nonEmpty(answer);
    return value == null ? const [] : [value];
  }
  if (answer is List) {
    return answer.expand(_answerValues).toList(growable: false);
  }
  if (answer is Map) {
    for (final key in ['label', 'option', 'answer', 'value']) {
      final value = answer[key];
      if (value != null) return _answerValues(value);
    }
  }
  final value = answer.toString().trim();
  return value.isEmpty ? const [] : [value];
}

String? _otherAnswerValue(String value) {
  final match = RegExp(
    r'^\s*other(?:\s+answer)?\s*:\s*(.*?)\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match != null) return _nonEmpty(match.group(1));
  if (value.toLowerCase() == 'other' || value.toLowerCase() == 'other answer') {
    return null;
  }
  return value;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
