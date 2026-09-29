import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';

/// Local admin layout prototype. Coordinates are normalized to the artwork,
/// never to a particular phone. Confirming does not publish a global layout.
class TitleLayoutGuideRoyalClean extends StatefulWidget {
  final Widget child;
  final double defaultY;
  const TitleLayoutGuideRoyalClean({
    super.key,
    required this.child,
    required this.defaultY,
  });
  @override
  State<TitleLayoutGuideRoyalClean> createState() => _TitleLayoutGuideState();
}

class _TitleLayoutGuideState extends State<TitleLayoutGuideRoyalClean> {
  final _access = AccountAccessRoyalClean.instance;
  Offset? _savedPosition, _draftPosition;
  double _savedFont = 16, _draftFont = 16;
  bool _editing = false, _saving = false;
  String? _uid;
  int _loadVersion = 0;
  Offset _startFocal = Offset.zero, _startPosition = Offset.zero;
  double _startFont = 16;
  bool get _admin =>
      _access.value.status == AccountAccessStatus.admin && _uid != null;
  String get _key => 'layout_guide.my_property.title.v1.$_uid';
  Offset get _defaultPosition => Offset(.5, widget.defaultY);

  @override
  void initState() {
    super.initState();
    _access.addListener(_accountChanged);
    _accountChanged();
  }

  void _accountChanged() {
    final uid = _access.value.status == AccountAccessStatus.admin
        ? _access.value.identity?.uid
        : null;
    if (uid == _uid) return;
    _uid = uid;
    _editing = false;
    _savedPosition = null;
    _savedFont = 16;
    final version = ++_loadVersion;
    if (mounted) setState(() {});
    if (uid != null) _load(version);
  }

  Future<void> _load(int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || version != _loadVersion) return;
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final x = (data['x'] as num).toDouble();
      final y = (data['y'] as num).toDouble();
      final font = (data['fontSize'] as num).toDouble();
      if (!x.isFinite || !y.isFinite || !font.isFinite) return;
      if (_editing) return;
      setState(() {
        _savedPosition = Offset(x.clamp(0, 1), y.clamp(0, 1));
        _savedFont = font.clamp(10, 48);
      });
    } catch (_) {
      // Invalid or unavailable local drafts never prevent opening the page.
    }
  }

  @override
  void dispose() {
    _loadVersion++;
    _access.removeListener(_accountChanged);
    super.dispose();
  }

  void _begin() {
    if (!_admin) return;
    HapticFeedback.lightImpact();
    setState(() {
      _draftPosition = _savedPosition ?? _defaultPosition;
      _draftFont = _savedFont;
      _editing = true;
    });
  }

  Map<String, Object> get _export => {
    'element': 'my_property.title',
    'version': 1,
    'canvasWidth': 432,
    'canvasHeight': 768,
    'anchor': 'topCenter',
    'x': _draftPosition!.dx,
    'y': _draftPosition!.dy,
    'fontSize': _draftFont,
  };
  Future<void> _confirm() async {
    if (!_admin || _saving) return;
    final uid = _uid;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || !_admin || _uid != uid) return;
      final saved = await prefs.setString(_key, jsonEncode(_export));
      if (!saved) throw StateError('Local save failed');
      if (!mounted || !_admin || _uid != uid) return;
      setState(() {
        _savedPosition = _draftPosition;
        _savedFont = _draftFont;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ajuste salvo neste dispositivo. Segure o título para editar ou copiar as medidas.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_editing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) setState(() => _editing = false);
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = math.max(screen.width / 432, screen.height / 768);
        final origin = Offset(
          (screen.width - 432 * scale) / 2,
          (screen.height - 768 * scale) / 2,
        );
        final position = _editing
            ? _draftPosition!
            : (_savedPosition ?? _defaultPosition);
        final font = _editing ? _draftFont : _savedFont;
        final style = TextStyle(
          color: const Color(0xFFFFB9DE),
          fontSize: font * scale,
          fontWeight: FontWeight.w500,
          shadows: const [Shadow(color: Color(0xAAFF7EC6), blurRadius: 8)],
        );
        final painter = TextPainter(
          text: TextSpan(text: 'My propriedade', style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final titleWidth = math.min(painter.width + 16, screen.width);
        final titleHeight = painter.height + 12;
        Offset bounded(Offset normalized) {
          final p =
              origin +
              Offset(normalized.dx * 432 * scale, normalized.dy * 768 * scale);
          final x = p.dx.clamp(titleWidth / 2, screen.width - titleWidth / 2);
          final y = p.dy.clamp(
            MediaQuery.paddingOf(context).top,
            math.max(
              MediaQuery.paddingOf(context).top,
              screen.height -
                  titleHeight -
                  MediaQuery.paddingOf(context).bottom,
            ),
          );
          return Offset(
            (x - origin.dx) / (432 * scale),
            (y - origin.dy) / (768 * scale),
          );
        }

        final visible = bounded(position);
        final center =
            origin + Offset(visible.dx * 432 * scale, visible.dy * 768 * scale);
        painter.dispose();
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_editing)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(color: Colors.black.withValues(alpha: .12)),
                ),
              ),
            Positioned(
              left: center.dx - titleWidth / 2,
              top: center.dy,
              width: titleWidth,
              height: titleHeight,
              child: GestureDetector(
                key: const ValueKey('layout-guide-title'),
                behavior: HitTestBehavior.opaque,
                onLongPress: _admin && !_editing ? _begin : null,
                child: Semantics(
                  label: 'My propriedade',
                  hint: _admin ? 'Segure para ajustar posição e tamanho' : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: _editing
                        ? BoxDecoration(
                            border: Border.all(color: Colors.cyanAccent),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Text(
                      'My propriedade',
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            if (_editing) ...[
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('layout-guide-gestures'),
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _saving
                      ? null
                      : (details) {
                          _startFocal = details.localFocalPoint;
                          _startPosition = visible;
                          _startFont = _draftFont;
                        },
                  onScaleUpdate: _saving
                      ? null
                      : (details) => setState(() {
                          final delta = details.localFocalPoint - _startFocal;
                          _draftFont = (_startFont * details.scale).clamp(
                            10,
                            48,
                          );
                          _draftPosition = bounded(
                            _startPosition +
                                Offset(
                                  delta.dx / (432 * scale),
                                  delta.dy / (768 * scale),
                                ),
                          );
                        }),
                ),
              ),
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: Card(
                    color: const Color(0xEE082538),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Guia • My propriedade\nArraste com um ou dois dedos. Aproxime ou afaste dois dedos para ajustar o tamanho.\nX ${(visible.dx * 100).toStringAsFixed(1)}% · Y ${(visible.dy * 100).toStringAsFixed(1)}% · ${font.toStringAsFixed(1)} px',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
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
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _editing = false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _draftPosition = _defaultPosition;
                                    _draftFont = 16;
                                  }),
                            child: const Text('Restaurar'),
                          ),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: jsonEncode(_export)),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Medidas copiadas para aplicar no código.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Copiar medidas'),
                          ),
                          FilledButton(
                            onPressed: _saving ? null : _confirm,
                            child: Text(_saving ? 'Salvando…' : 'OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
