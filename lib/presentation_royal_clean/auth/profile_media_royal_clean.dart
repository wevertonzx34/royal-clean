import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';

class ProfileMediaRoyalClean extends StatefulWidget {
  final String uid;
  final String kind;
  final String path;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onBusyChanged;
  const ProfileMediaRoyalClean({
    super.key,
    required this.uid,
    required this.kind,
    required this.path,
    required this.enabled,
    required this.onChanged,
    this.onBusyChanged,
  });
  @override
  State<ProfileMediaRoyalClean> createState() => _ProfileMediaState();
}

class _ProfileMediaState extends State<ProfileMediaRoyalClean> {
  Uint8List? _bytes;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileMediaRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    if (widget.path.isEmpty) {
      if (mounted) setState(() => _bytes = null);
      return;
    }
    try {
      final bytes = await FirebaseStorage.instance
          .ref(widget.path)
          .getData(2 * 1024 * 1024);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar a imagem.');
      }
    }
  }

  Future<void> _pick() async {
    widget.onBusyChanged?.call(true);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (selected == null) return;
      final source = await selected.readAsBytes();
      if (source.length > 10 * 1024 * 1024) throw StateError('large');
      final codec = await ui.instantiateImageCodec(
        source,
        targetWidth: 512,
        allowUpscaling: false,
      );
      Uint8List bytes;
      try {
        final frame = await codec.getNextFrame();
        try {
          bytes = (await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      if (bytes.length > 2 * 1024 * 1024) throw StateError('large');
      final path = 'profile_media/${widget.uid}/${widget.kind}.png';
      await FirebaseStorage.instance
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'image/png'));
      if (!mounted) return;
      setState(() => _bytes = bytes);
      widget.onChanged(path);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível enviar. Escolha uma imagem menor e tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              widget.kind == 'photo' ? 40 : 12,
            ),
            child: SizedBox(
              width: 72,
              height: 72,
              child: _bytes == null
                  ? Icon(
                      widget.kind == 'photo'
                          ? Icons.person_outline
                          : Icons.storefront,
                      size: 40,
                    )
                  : Image.memory(_bytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutButtonRoyalClean(
              id: 'profile_media_royal_clean.control_01',
              child: OutlinedButton.icon(
                onPressed: tactileTapRoyalClean(
                  widget.enabled && !_busy ? _pick : null,
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _busy
                      ? 'Enviando…'
                      : widget.kind == 'photo'
                      ? 'Foto de perfil'
                      : 'Logo da empresa',
                ),
              ),
            ),
          ),
          if (widget.path.isNotEmpty)
            LayoutButtonRoyalClean(
              id: 'profile_media_royal_clean.control_02',
              child: IconButton(
                tooltip: 'Remover imagem',
                onPressed: tactileTapRoyalClean(
                  widget.enabled && !_busy ? () => widget.onChanged('') : null,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
