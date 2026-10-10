import 'package:ccpocket/features/chat_session/question_answer_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('questionAnswerTranscript', () {
    test('preserves every option, description, header and selected choice', () {
      final transcript = questionAnswerTranscript(
        input: const {
          'questions': [
            {
              'id': 'sound',
              'question': 'Which sound should the garden use?',
              'header': 'Garden sound',
              'options': [
                {'label': 'Forest birdsong', 'description': 'Morning birds'},
                {'label': 'Rainfall', 'description': 'Soft rain'},
              ],
            },
          ],
        },
        result: 'Forest birdsong',
      );

      expect(transcript, isNotNull);
      final question = transcript!.questions.single;
      expect(question.header, 'Garden sound');
      expect(question.question, 'Which sound should the garden use?');
      expect(question.options, hasLength(2));
      expect(question.options[0].label, 'Forest birdsong');
      expect(question.options[0].description, 'Morning birds');
      expect(question.options[0].selected, isTrue);
      expect(question.options[1].label, 'Rainfall');
      expect(question.options[1].description, 'Soft rain');
      expect(question.options[1].selected, isFalse);
    });

    test('shows free-text answers alongside selected multi-select options', () {
      final transcript = questionAnswerTranscript(
        input: const {
          'questions': [
            {
              'id': 'zones',
              'question': 'Which zones?',
              'multiSelect': true,
              'options': [
                {'label': 'Forest', 'description': 'Wooded area'},
                {'label': 'Desert', 'description': 'Dry area'},
              ],
            },
          ],
        },
        result: '{"answers":{"zones":["Forest", "A hidden cave"]}}',
      );

      final question = transcript!.questions.single;
      expect(question.options.first.selected, isTrue);
      expect(question.options.last.selected, isFalse);
      expect(question.freeTextAnswer, 'A hidden cave');
      expect(transcript.plainText, contains('Forest, A hidden cave'));
    });
  });

  group('questionAnswerTranscriptText', () {
    test('formats a direct single-question answer', () {
      expect(
        questionAnswerTranscriptText(
          input: const {
            'questions': [
              {'question': 'Which sound?', 'options': []},
            ],
          },
          result: 'Forest birdsong',
        ),
        'Question: Which sound?\nAnswer: Forest birdsong',
      );
    });

    test('maps Codex answers by question ID, including duplicate text', () {
      expect(
        questionAnswerTranscriptText(
          input: const {
            'questions': [
              {'id': 'first', 'question': 'Which version?'},
              {'id': 'second', 'question': 'Which version?'},
            ],
          },
          result: '{"answers":{"first":"Stable","second":"Preview"}}',
        ),
        'Question: Which version?\nAnswer: Stable\n\n'
        'Question: Which version?\nAnswer: Preview',
      );
    });

    test(
      'maps SDK answers by question text and formats multi-select values',
      () {
        expect(
          questionAnswerTranscriptText(
            input: const {
              'questions': [
                {'question': 'Which channels?', 'multiSelect': true},
              ],
            },
            result:
                '{"questions":[{"question":"Which channels?"}],'
                '"answers":{"Which channels?":["Issues","Pull requests"]}}',
          ),
          'Question: Which channels?\nAnswer: Issues, Pull requests',
        );
      },
    );

    test('does not invent an answer from a legacy status label', () {
      expect(
        questionAnswerTranscriptText(
          input: const {
            'questions': [
              {'question': 'Which sound?'},
            ],
          },
          result: 'Answered',
        ),
        isNull,
      );
    });
  });
}
