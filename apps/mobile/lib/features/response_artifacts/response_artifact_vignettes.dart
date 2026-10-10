import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../theme/app_spacing.dart';
import '../../models/messages.dart';
import '../../widgets/file_type_icon.dart';
import '../file_peek/file_path_syntax.dart';
import '../generated_image_preview/generated_image_preview_item.dart';
import '../generated_image_preview/generated_image_preview_mapper.dart';
import '../generated_image_preview/widgets/generated_image_chat_group.dart';
import 'workspace_output_links.dart';

typedef _CachedResponseImages = ({
  String? httpBaseUrl,
  List<GeneratedImagePreviewItem> items,
});

final _responseImages = Expando<_CachedResponseImages>('response images');

List<GeneratedImagePreviewItem> responseImagesForMessage(
  ToolResultMessage message, {
  required String? httpBaseUrl,
}) {
  final cached = _responseImages[message];
  if (cached != null && cached.httpBaseUrl == httpBaseUrl) return cached.items;
  final items = generatedImageItemsFromToolResults([
    message,
  ], httpBaseUrl: httpBaseUrl);
  _responseImages[message] = (httpBaseUrl: httpBaseUrl, items: items);
  return items;
}

/// Output attachments stay accessible outside collapsible tool content.
class ResponseArtifactVignettes extends StatelessWidget {
  final List<GeneratedImagePreviewItem> images;
  final List<WorkspaceOutputLink> files;
  final FilePathTapCallback? onFileTap;

  const ResponseArtifactVignettes({
    super.key,
    this.images = const [],
    this.files = const [],
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && (files.isEmpty || onFileTap == null)) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const ValueKey('response_artifact_vignettes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.isNotEmpty)
          GeneratedImageChatGroup(items: images, compact: true),
        if (files.isNotEmpty && onFileTap != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.bubbleMarginH,
              vertical: 4,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in files)
                  _WorkspaceFileVignette(
                    file: file,
                    onTap: () => onFileTap!(file.path),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkspaceFileVignette extends StatelessWidget {
  final WorkspaceOutputLink file;
  final VoidCallback onTap;

  const _WorkspaceFileVignette({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filePath = file.path.replaceFirst(RegExp(r'(:\d+){1,2}$'), '');
    final name = path.posix.basename(filePath.replaceAll('\\', '/'));
    return SizedBox(
      width: 220,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('response_file_vignette_${file.path}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FileTypeIcon(path: filePath, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.label.isEmpty ? name : file.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (file.label.isNotEmpty && file.label != name)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
