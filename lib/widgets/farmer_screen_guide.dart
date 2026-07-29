import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/screen_guide_step.dart';
import '../utils/farmer_guide_access.dart';
import 'farmer_help_widgets.dart';

class FarmerScreenGuide extends StatefulWidget {
  const FarmerScreenGuide({
    super.key,
    required this.steps,
  });

  final List<ScreenGuideStep> steps;

  static Future<void> show(
    BuildContext context,
    List<ScreenGuideStep> steps, {
    bool ignoreRoleGate = false,
  }) {
    if (steps.isEmpty) return Future.value();

    if (!ignoreRoleGate) {
      try {
        final container = ProviderScope.containerOf(context);
        if (!FarmerGuideAccess.isGuideEnabledForContainer(container)) {
          return Future.value();
        }
      } catch (_) {
        // Nema ProviderScope-a — nastavi bez globalne blokade.
      }
    }

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      pageBuilder: (dialogContext, _, __) {
        return FarmerScreenGuide(steps: steps);
      },
    );
  }

  @override
  State<FarmerScreenGuide> createState() => _FarmerScreenGuideState();
}

class _FarmerScreenGuideState extends State<FarmerScreenGuide> {
  static const _scrollAnimDuration = Duration(milliseconds: 420);
  static const _targetScrollAlignment = 0.42;

  int _stepIndex = 0;
  Rect? _highlight;
  ScrollPosition? _trackedScrollPosition;
  bool _highlightRefreshScheduled = false;

  ScreenGuideStep get _currentStep => widget.steps[_stepIndex];

  bool get _isLastStep => _stepIndex >= widget.steps.length - 1;

  Rect? _targetRect() {
    final key = _currentStep.targetKey;
    if (key?.currentContext == null) return null;

    final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final offset = renderBox.localToGlobal(Offset.zero);
    final padding = _currentStep.highlightPadding;
    return Rect.fromLTWH(
      offset.dx - padding.left,
      offset.dy - padding.top,
      renderBox.size.width + padding.horizontal,
      renderBox.size.height + padding.vertical,
    );
  }

  ScrollPosition? _scrollPositionForStep(ScreenGuideStep step) {
    final ctx = step.targetKey?.currentContext;
    if (ctx == null) return null;
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null || !scrollable.position.hasContentDimensions) {
      return null;
    }
    return scrollable.position;
  }

  ScrollPosition? _activeScrollPosition() {
    final current = _scrollPositionForStep(_currentStep);
    if (current != null) return current;

    for (final step in widget.steps) {
      final position = _scrollPositionForStep(step);
      if (position != null) return position;
    }
    return null;
  }

  void _detachScrollListener() {
    _trackedScrollPosition?.removeListener(_handleScrollUpdate);
    _trackedScrollPosition = null;
  }

  void _attachScrollListener() {
    _detachScrollListener();
    final position =
        _scrollPositionForStep(_currentStep) ?? _activeScrollPosition();
    if (position == null) return;
    _trackedScrollPosition = position;
    position.addListener(_handleScrollUpdate);
  }

  void _handleScrollUpdate() {
    if (!mounted) return;
    _scheduleHighlightRefresh();
  }

  void _scheduleHighlightRefresh() {
    _refreshHighlight();
    if (_highlightRefreshScheduled) return;
    _highlightRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _highlightRefreshScheduled = false;
      if (mounted) _refreshHighlight();
    });
  }

  Future<void> _ensureTargetVisible() async {
    final key = _currentStep.targetKey;
    final ctx = key?.currentContext;
    if (ctx == null) return;

    try {
      await Scrollable.ensureVisible(
        ctx,
        duration: _scrollAnimDuration,
        curve: Curves.easeInOutCubic,
        alignment: _targetScrollAlignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } catch (_) {
      // Element nije u scrollable listi — ignoriraj.
    }
  }

  void _scrollUnderlyingBy(double delta) {
    if (delta == 0) return;
    final position = _activeScrollPosition();
    if (position == null) return;

    final next = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next == position.pixels) return;

    position.jumpTo(next);
    _scheduleHighlightRefresh();
  }

  void _refreshHighlight() {
    if (!mounted) return;
    setState(() => _highlight = _targetRect());
  }

  Future<void> _syncStepView() async {
    _attachScrollListener();
    await _ensureTargetVisible();
    if (!mounted) return;
    _scheduleHighlightRefresh();
    await Future<void>.delayed(_scrollAnimDuration);
    if (mounted) _scheduleHighlightRefresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStepView());
  }

  @override
  void dispose() {
    _detachScrollListener();
    super.dispose();
  }

  void _next() {
    if (_isLastStep) {
      _close();
      return;
    }
    _detachScrollListener();
    setState(() => _stepIndex++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStepView());
  }

  void _close() => Navigator.of(context).pop();

  Alignment _bubbleAlignment(Rect? highlight, Size screenSize) {
    if (highlight == null) return Alignment.center;
    if (highlight.center.dy > screenSize.height * 0.52) {
      return Alignment.topCenter;
    }
    return Alignment.bottomCenter;
  }

  Widget _overlayLayer() {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _scrollUnderlyingBy(event.scrollDelta.dy);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          _scrollUnderlyingBy(-details.delta.dy);
        },
        onVerticalDragEnd: (_) => _scheduleHighlightRefresh(),
        child: CustomPaint(
          painter: _SpotlightPainter(highlightRect: _highlight),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _highlight;
    final screenSize = MediaQuery.sizeOf(context);
    final bubbleAlignment = _bubbleAlignment(highlight, screenSize);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(child: _overlayLayer()),
          if (highlight != null) ...[
            Positioned(
              left: highlight.left,
              top: highlight.top,
              width: highlight.width,
              height: highlight.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade200.withValues(alpha: 0.75),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_currentStep.highlightLabelKey != null)
              Positioned(
                left: highlight.left,
                top: highlight.top,
                width: highlight.width,
                height: highlight.height,
                child: IgnorePointer(
                  child: Center(
                    child: FarmerGuideFabReplica(
                      label: farmerGuideTr(
                        context,
                        _currentStep.highlightLabelKey!,
                        fallbacks: const {
                          'hr': '+ Dodaj životinju',
                          'de': '+ Tier hinzufügen',
                          'en': '+ Add animal',
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
          Positioned.fill(
            child: Align(
              alignment: bubbleAlignment,
              child: FarmerGuideBubbleCard(
                titleKey: _currentStep.titleKey,
                bodyKey: _currentStep.bodyKey,
                stepNumber: _stepIndex + 1,
                totalSteps: widget.steps.length,
                onNext: _next,
                onClose: _close,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FarmerHelperIcon(),
                    const SizedBox(width: 6),
                    Text(
                      farmerGuideTr(
                        context,
                        'farmer_helper_reflector',
                        fallbacks: const {
                          'hr': 'Pomoćnik',
                          'de': 'Assistent',
                          'en': 'Assistant',
                        },
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (highlight == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: IgnorePointer(
                child: Text(
                  farmerGuideTr(
                    context,
                    'farmer_helper_scroll_hint',
                    fallbacks: const {
                      'hr':
                          'Povucite prstom gore ili dolje po tamnom dijelu da listate ekran. Svjetlo se automatski centrira na označeno polje.',
                      'bs':
                          'Povucite prstom gore ili dolje po tamnom dijelu da listate ekran. Svjetlo se automatski centrira na označeno polje.',
                      'sr':
                          'Povucite prstom gore ili dole po tamnom delu da listate ekran. Svetlo se automatski centrira na označeno polje.',
                      'de':
                          'Wischen Sie auf dem dunklen Bereich nach oben/unten zum Scrollen. Das Spotlight zentriert sich automatisch.',
                      'en':
                          'Drag up or down on the dark area to scroll. The spotlight auto-centers on the highlighted field.',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.highlightRect});

  final Rect? highlightRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (highlightRect != null) {
      final hole = RRect.fromRectAndRadius(
        highlightRect!,
        const Radius.circular(12),
      );
      fullPath.addRRect(hole);
      fullPath.fillType = PathFillType.evenOdd;
    }

    canvas.drawPath(fullPath, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect;
  }
}
