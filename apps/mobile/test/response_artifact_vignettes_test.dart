import 'package:ccpocket/features/generated_image_preview/generated_image_preview_item.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_preview_screen.dart';
import 'package:ccpocket/features/response_artifacts/response_artifact_vignettes.dart';
import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Uint8List imageBytes;
  setUpAll(() async {
    imageBytes = (await rootBundle.load('assets/icon.png')).buffer
        .asUint8List();
  });

  testWidgets(
    'each image has a visible clickable vignette, including the fifth',
    (tester) async {
      final items = [
        for (var index = 0; index < 5; index++)
          GeneratedImagePreviewItem(
            id: 'capture-$index',
            bytes: imageBytes,
            mimeType: 'image/png',
            prompt: '',
          ),
      ];
      await tester.pumpWidget(_wrap(ResponseArtifactVignettes(images: items)));
      await tester.pumpAndSettle();
      for (var index = 0; index < 5; index++) {
        expect(
          find.byKey(ValueKey('generated_image_chat_thumbnail_$index')),
          findsOneWidget,
        );
      }
      final last = find.byKey(
        const ValueKey('generated_image_chat_thumbnail_4'),
      );
      expect(tester.getSize(last), const Size(112, 112));
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.byType(GeneratedImagePreviewScreen), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);
    },
  );

  testWidgets(
    'file vignette passes the complete resolved destination to File Peek',
    (tester) async {
      String? openedPath;
      await tester.pumpWidget(
        _wrap(
          ResponseArtifactVignettes(
            files: const [
              WorkspaceOutputLink(
                path: '/workspace/reports/Release review.pdf:18',
                label: 'Release review',
              ),
            ],
            onFileTap: (path) => openedPath = path,
          ),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey(
            'response_file_vignette_/workspace/reports/Release review.pdf:18',
          ),
        ),
      );
      expect(openedPath, '/workspace/reports/Release review.pdf:18');
      expect(find.text('Release review.pdf'), findsOneWidget);
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);
