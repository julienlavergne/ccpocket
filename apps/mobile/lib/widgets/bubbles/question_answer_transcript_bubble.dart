import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class QuestionAnswerTranscriptBubble extends StatelessWidget {
  final String text;

  const QuestionAnswerTranscriptBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('question_answer_transcript_bubble'),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.bubbleMarginH,
          vertical: 4,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: appColors.toolBubble,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: appColors.toolBubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_outlined, size: 14, color: appColors.toolIcon),
                const SizedBox(width: 6),
                Text(
                  'AskUserQuestion',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
