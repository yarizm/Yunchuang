import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

typedef PdfSelectionAction = void Function(String text, int pageIndex);

double pdfCropScale(double cropAmount) {
  final normalized = cropAmount.clamp(0.0, 0.2);
  return 1 / (1 - normalized * 2);
}

List<double> pdfContrastMatrix(double contrast) {
  final normalized = contrast.clamp(1.0, 2.0);
  final translation = 128 * (1 - normalized);
  return <double>[
    normalized,
    0,
    0,
    0,
    translation,
    0,
    normalized,
    0,
    0,
    translation,
    0,
    0,
    normalized,
    0,
    translation,
    0,
    0,
    0,
    1,
    0,
  ];
}

bool pdfDoublePageActive({
  required bool enabled,
  required Orientation orientation,
}) {
  return enabled && orientation == Orientation.landscape;
}

int resolvePdfSelectionPageIndex({
  required int controllerPageNumber,
  required int pageCount,
  int? selectedLinePageIndex,
}) {
  if (pageCount <= 0) return 0;
  final pageIndex = selectedLinePageIndex ?? controllerPageNumber - 1;
  return pageIndex.clamp(0, pageCount - 1);
}

class PdfPageEffects extends StatelessWidget {
  final double cropAmount;
  final double contrast;
  final Widget child;

  const PdfPageEffects({
    super.key,
    required this.cropAmount,
    required this.contrast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedCrop = cropAmount.clamp(0.0, 0.2);
    final normalizedContrast = contrast.clamp(1.0, 2.0);
    Widget result = child;

    if (normalizedCrop > 0) {
      result = ClipRect(
        key: const Key('pdf-crop-clip'),
        child: Transform.scale(
          key: const Key('pdf-crop-transform'),
          scale: pdfCropScale(normalizedCrop),
          child: result,
        ),
      );
    }
    if (normalizedContrast > 1) {
      result = ColorFiltered(
        key: const Key('pdf-contrast-filter'),
        colorFilter: ColorFilter.matrix(
          pdfContrastMatrix(normalizedContrast),
        ),
        child: result,
      );
    }

    return RepaintBoundary(child: result);
  }
}

class PdfReader extends StatefulWidget {
  final String filePath;
  final int initialPage;
  final double cropAmount;
  final double contrast;
  final bool enableDoublePage;
  final ValueChanged<int>? onPageChanged;
  final PdfSelectionAction? onVocabularyAction;
  final PdfSelectionAction? onTranslateAction;

  const PdfReader({
    super.key,
    required this.filePath,
    this.initialPage = 0,
    this.cropAmount = 0,
    this.contrast = 1,
    this.enableDoublePage = false,
    this.onPageChanged,
    this.onVocabularyAction,
    this.onTranslateAction,
  });

  @override
  State<PdfReader> createState() => PdfReaderState();
}

class PdfReaderState extends State<PdfReader> {
  late final PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey =
      GlobalKey<SfPdfViewerState>();
  OverlayEntry? _selectionOverlay;
  int? _selectionPageIndex;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _removeSelectionOverlay();
    _pdfViewerController.dispose();
    super.dispose();
  }

  void goToPage(int pageIndex) {
    _clearSelection();
    // SfPdfViewer pages are 1-indexed, but chapterIndex is 0-indexed
    _pdfViewerController.jumpToPage(pageIndex + 1);
  }

  void _handleTextSelection(PdfTextSelectionChangedDetails details) {
    _removeSelectionOverlay();
    final selectedText = details.selectedText?.trim();
    final region = details.globalSelectedRegion;
    if (!mounted ||
        selectedText == null ||
        selectedText.isEmpty ||
        region == null) {
      _selectionPageIndex = null;
      return;
    }
    final selectedLines =
        _pdfViewerKey.currentState?.getSelectedTextLines() ?? const [];
    _selectionPageIndex =
        selectedLines.isEmpty ? null : selectedLines.first.pageNumber;
    final overlay = Overlay.of(context);
    _selectionOverlay = OverlayEntry(
      builder: (overlayContext) {
        final mediaQuery = MediaQuery.of(overlayContext);
        final toolbarWidth = 44.0 +
            (widget.onVocabularyAction == null ? 0 : 92) +
            (widget.onTranslateAction == null ? 0 : 84);
        final left = (region.center.dx - toolbarWidth / 2)
            .clamp(8.0, mediaQuery.size.width - toolbarWidth - 8.0)
            .toDouble();
        final preferredTop = region.top - 52;
        final safeTop = mediaQuery.padding.top + 8;
        final top = preferredTop >= safeTop
            ? preferredTop
            : (region.bottom + 8).clamp(
                safeTop,
                mediaQuery.size.height - mediaQuery.padding.bottom - 52,
              );
        return Positioned(
          left: left,
          top: top.toDouble(),
          width: toolbarWidth,
          child: PdfSelectionActionBar(
            onCopy: () => _copySelection(selectedText),
            onVocabulary: widget.onVocabularyAction == null
                ? null
                : () => _performSelectionAction(
                      widget.onVocabularyAction!,
                      selectedText,
                    ),
            onTranslate: widget.onTranslateAction == null
                ? null
                : () => _performSelectionAction(
                      widget.onTranslateAction!,
                      selectedText,
                    ),
          ),
        );
      },
    );
    overlay.insert(_selectionOverlay!);
  }

  Future<void> _copySelection(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clearSelection();
  }

  void _performSelectionAction(
    PdfSelectionAction action,
    String selectedText,
  ) {
    if (_pdfViewerController.pageCount <= 0) return;
    final pageIndex = resolvePdfSelectionPageIndex(
      selectedLinePageIndex: _selectionPageIndex,
      controllerPageNumber: _pdfViewerController.pageNumber,
      pageCount: _pdfViewerController.pageCount,
    );
    _clearSelection();
    action(selectedText, pageIndex);
  }

  void _clearSelection() {
    _removeSelectionOverlay();
    _selectionPageIndex = null;
    _pdfViewerController.clearSelection();
  }

  void _removeSelectionOverlay() {
    _selectionOverlay?.remove();
    _selectionOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final useDoublePage = pdfDoublePageActive(
      enabled: widget.enableDoublePage,
      orientation: MediaQuery.orientationOf(context),
    );
    return PdfPageEffects(
      cropAmount: widget.cropAmount,
      contrast: widget.contrast,
      child: SfPdfViewer.file(
        File(widget.filePath),
        key: _pdfViewerKey,
        controller: _pdfViewerController,
        initialPageNumber: widget.initialPage + 1,
        canShowScrollHead: false,
        canShowPaginationDialog: false,
        canShowTextSelectionMenu: false,
        enableTextSelection: true,
        pageLayoutMode: useDoublePage
            ? PdfPageLayoutMode.continuous
            : PdfPageLayoutMode.single,
        scrollDirection: useDoublePage
            ? PdfScrollDirection.horizontal
            : PdfScrollDirection.vertical,
        pageSpacing: useDoublePage ? 8 : 4,
        onTextSelectionChanged: _handleTextSelection,
        onPageChanged: (PdfPageChangedDetails details) {
          _removeSelectionOverlay();
          _selectionPageIndex = null;
          if (widget.onPageChanged != null) {
            // Send 0-indexed page back
            widget.onPageChanged!(details.newPageNumber - 1);
          }
        },
      ),
    );
  }
}

class PdfSelectionActionBar extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback? onVocabulary;
  final VoidCallback? onTranslate;

  const PdfSelectionActionBar({
    super.key,
    required this.onCopy,
    this.onVocabulary,
    this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: '复制',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 20),
              ),
            ),
            if (onVocabulary != null) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child: TextButton.icon(
                  key: const Key('pdf-vocabulary-action'),
                  onPressed: onVocabulary,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('查词'),
                ),
              ),
            ],
            if (onTranslate != null) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child: TextButton.icon(
                  key: const Key('pdf-translation-action'),
                  onPressed: onTranslate,
                  icon: const Icon(Icons.translate, size: 18),
                  label: const Text('翻译'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
