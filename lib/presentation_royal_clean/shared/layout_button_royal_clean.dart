import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core_royal_clean/services/layout_approvals_royal_clean.dart';

/// Stable, opt-in wrapper: unchanged original layout until an admin confirms.
/// Long press is reserved for the guide only on buttons without a business
/// long-press action. Data rows keep their existing detail/product gestures.
class LayoutButtonRoyalClean extends StatefulWidget {
  final String id;
  final String? instanceKey;
  final Widget child;
  final Future<Uint8List?> Function()? capturePreview;
  const LayoutButtonRoyalClean({
    super.key,
    required this.id,
    this.instanceKey,
    required this.child,
    this.capturePreview,
  });
  @override
  State<LayoutButtonRoyalClean> createState() => _LayoutButtonState();
}

class _LayoutButtonState extends State<LayoutButtonRoyalClean> {
  final _store = LayoutApprovalsRoyalClean.instance;
  final _boundary = GlobalKey();
  final _target = GlobalKey();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  Size? _originalSize;
  Size? _viewport;
  String _scope = 'app';
  String get _id =>
      '$_scope/${widget.id}${widget.instanceKey == null ? '' : '#${base64Url.encode(utf8.encode(widget.instanceKey!)).replaceAll('=', '')}'}';
  bool _opening = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewport = MediaQuery.sizeOf(context);
    if (viewport != _viewport) {
      _originalSize = null;
      _viewport = viewport;
    }
    context.visitAncestorElements((element) {
      final name = element.widget.runtimeType.toString();
      if (name.contains('Page') &&
          !name.contains('PageRoute') &&
          !name.startsWith('_Modal')) {
        _scope = name;
        return false;
      }
      return true;
    });
  }

  @override
  void initState() {
    super.initState();
    _store.start();
    _store.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  Future<void> _edit() async {
    if (!_store.authorized || _opening) return;
    _opening = true;
    try {
      final box =
          _boundary.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (box == null || !box.hasSize) return;
      final originBox =
          _target.currentContext?.findRenderObject() as RenderBox?;
      if (originBox == null) return;
      final rect = MatrixUtils.transformRect(
        originBox.getTransformTo(null),
        Offset.zero & originBox.size,
      );
      Uint8List? bytes;
      try {
        if (widget.capturePreview != null) {
          bytes = await widget.capturePreview!();
        } else {
          final image = await box.toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          bytes = data?.buffer.asUint8List();
          image.dispose();
        }
      } catch (_) {
        /* The editor still works with a labelled placeholder. */
      }
      if (!mounted || !_store.authorized) return;
      _originalSize = originBox.size;
      HapticFeedback.lightImpact();
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: .28),
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, a, b) =>
            _ButtonEditor(id: _id, origin: rect, image: bytes),
      );
    } finally {
      _opening = false;
    }
  }

  Widget _interactiveChild() => RepaintBoundary(
    key: _boundary,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: _store.authorized ? _edit : null,
      child: Semantics(
        label: widget.child is IconButton
            ? (widget.child as IconButton).tooltip
            : null,
        hint: _store.authorized
            ? 'Segure para ajustar posição e tamanho'
            : null,
        child: TooltipVisibility(
          visible: !_store.authorized,
          child: widget.child,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final record = _store.get(_id);
    if ((!_store.authorized && record.original) ||
        Overlay.maybeOf(context) == null) {
      return widget.child;
    }
    final adjusted = !record.original && _originalSize != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _target.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && _originalSize == null) {
        setState(() => _originalSize = box.size);
      }
      if (adjusted && !_portal.isShowing) {
        _portal.show();
      }
      if (!adjusted && _portal.isShowing) {
        _portal.hide();
      }
    });
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final box = _target.currentContext?.findRenderObject() as RenderBox?;
        if (!adjusted || box == null || !box.hasSize) {
          return const SizedBox.shrink();
        }
        final viewport = MediaQuery.sizeOf(context);
        final globalRect = MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
        final factor = box.size.width > 0
            ? globalRect.width / box.size.width
            : 1.0;
        final route = ModalRoute.of(this.context);
        if (route != null && !route.isCurrent) return const SizedBox.shrink();
        final scrollable = Scrollable.maybeOf(this.context);
        final scrollBox = scrollable?.context.findRenderObject();
        Rect clip = Offset.zero & viewport;
        if (scrollBox is RenderBox && scrollBox.hasSize) {
          clip = clip.intersect(
            MatrixUtils.transformRect(
              scrollBox.getTransformTo(null),
              Offset.zero & scrollBox.size,
            ),
          );
        }
        return Positioned.fill(
          child: ClipPath(
            clipper: _ViewportClip(clip),
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  offset: Offset(
                    record.dx * viewport.width / factor,
                    record.dy * viewport.height / factor,
                  ),
                  child: Transform.scale(
                    scale: record.scale,
                    alignment: Alignment.center,
                    child: SizedBox.fromSize(
                      size: box.size,
                      child: _interactiveChild(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        key: _target,
        link: _link,
        child: adjusted
            ? IgnorePointer(child: SizedBox.fromSize(size: _originalSize))
            : _interactiveChild(),
      ),
    );
  }
}

class _ViewportClip extends CustomClipper<Path> {
  final Rect rect;
  const _ViewportClip(this.rect);
  @override
  Path getClip(Size size) => Path()..addRect(rect);
  @override
  bool shouldReclip(_ViewportClip old) => rect != old.rect;
}

class _ButtonEditor extends StatefulWidget {
  final String id;
  final Rect origin;
  final Uint8List? image;
  const _ButtonEditor({required this.id, required this.origin, this.image});
  @override
  State<_ButtonEditor> createState() => _ButtonEditorState();
}

class _ButtonEditorState extends State<_ButtonEditor> {
  final _store = LayoutApprovalsRoyalClean.instance;
  late LayoutApprovalRoyalClean _draft = _store.get(widget.id);
  late LayoutApprovalRoyalClean _start = _draft;
  Offset _focal = Offset.zero;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _store.addListener(_accessChanged);
  }

  void _accessChanged() {
    if (!_store.authorized && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _store.removeListener(_accessChanged);
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.save(widget.id, _draft);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o ajuste.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center =
            widget.origin.center +
            Offset(_draft.dx * size.width, _draft.dy * size.height);
        final width = widget.origin.width * _draft.scale;
        final height = widget.origin.height * _draft.scale;
        return Stack(
          children: [
            Positioned(
              left: center.dx - width / 2,
              top: center.dy - height / 2,
              width: width,
              height: height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                  ),
                  child: widget.image == null
                      ? const ColoredBox(
                          color: Color(0xCC0B3447),
                          child: Center(
                            child: Text(
                              'Botão',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                      : Image.memory(widget.image!, fit: BoxFit.fill),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('button-guide-gestures'),
                behavior: HitTestBehavior.opaque,
                onScaleStart: _saving
                    ? null
                    : (details) {
                        _focal = details.localFocalPoint;
                        _start = _draft;
                      },
                onScaleUpdate: _saving
                    ? null
                    : (details) => setState(() {
                        final delta = details.localFocalPoint - _focal;
                        final scale = (_start.scale * details.scale).clamp(
                          .5,
                          2.5,
                        );
                        final halfW = (widget.origin.width * scale / 2).clamp(
                          0.0,
                          size.width / 2,
                        );
                        final halfH = (widget.origin.height * scale / 2).clamp(
                          0.0,
                          size.height / 2,
                        );
                        final x =
                            (widget.origin.center.dx +
                                    _start.dx * size.width +
                                    delta.dx)
                                .clamp(halfW, size.width - halfW);
                        final y =
                            (widget.origin.center.dy +
                                    _start.dy * size.height +
                                    delta.dy)
                                .clamp(halfH, size.height - halfH);
                        _draft = LayoutApprovalRoyalClean(
                          dx: (x - widget.origin.center.dx) / size.width,
                          dy: (y - widget.origin.center.dy) / size.height,
                          scale: scale,
                        );
                      }),
              ),
            ),
            Positioned(
              top: 0,
              left: 8,
              right: 8,
              child: SafeArea(
                bottom: false,
                child: Card(
                  color: const Color(0xF0082538),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Guia do botão\nArraste com um ou dois dedos. Use pinça para redimensionar.\nX ${(_draft.dx * 100).toStringAsFixed(1)}% · Y ${(_draft.dy * 100).toStringAsFixed(1)}% · ${(_draft.scale * 100).toStringAsFixed(0)}%\nOK salva neste dispositivo. Copie as medidas para oficializar no código.',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 8,
              right: 8,
              child: SafeArea(
                top: false,
                child: Card(
                  color: const Color(0xFF082538),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(
                                  () =>
                                      _draft = const LayoutApprovalRoyalClean(),
                                ),
                          child: const Text('Restaurar'),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _store.export()),
                                  );
                                },
                          child: const Text('Copiar aprovados'),
                        ),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Salvando…' : 'OK'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
