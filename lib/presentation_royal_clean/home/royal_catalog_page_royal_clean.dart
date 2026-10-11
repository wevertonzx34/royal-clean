import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core_royal_clean/services/royal_catalog_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import '../preview/product_categories_royal_clean.dart';
import '../preview/product_filters_royal_clean.dart';
import 'royal_price_benefit_page_royal_clean.dart';
import 'bling_data_page_royal_clean.dart';
import 'catalog_audit_card_royal_clean.dart';
import 'nfe_document_royal_clean.dart';
import '../preview/preview_page_royal_clean.dart';

const _navy = Color(0xFF092F43);
Widget _catalogBackground({required Widget child, bool enabled = true}) =>
    enabled
    ? Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/preview/royal-store/royal-stoque.webp',
            fit: BoxFit.cover,
            cacheWidth: 1080,
            excludeFromSemantics: true,
          ),
          child,
        ],
      )
    : child;
Widget _control(String id, Widget child) =>
    LayoutButtonRoyalClean(id: 'catalog.$id', child: child);
String _error(Object error) => error is FirebaseFunctionsException
    ? error.message ?? 'Não foi possível concluir. Tente novamente.'
    : 'Não foi possível concluir. Verifique a conexão e tente novamente.';
String _when(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Ainda não salvo';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class RoyalCatalogPageRoyalClean extends StatefulWidget {
  final bool production;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? load;
  final Stream<List<Map<String, dynamic>>>? storefront;
  const RoyalCatalogPageRoyalClean({
    super.key,
    this.production = false,
    this.load,
    this.storefront,
  });
  @override
  State<RoyalCatalogPageRoyalClean> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<RoyalCatalogPageRoyalClean> {
  late String _filter = widget.production ? 'available' : 'recipe';
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  String? _cursor, _failure;
  bool _busy = false;
  Map<String, String> get _filters => widget.production
      ? {
          'available': 'Disponíveis',
          'integrated': 'Integrados',
          'excluded': 'Excluídos',
        }
      : {
          'recipe': 'Receitas',
          'published': 'Publicado',
          'observation': 'Observação',
          'suspended': 'Suspensos',
        };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await (widget.load ?? RoyalCatalogRoyalClean.call)({
        'action': 'list',
        'mode': widget.production ? 'production' : 'products',
        'filter': _filter,
        if (more && _cursor != null) 'cursor': _cursor,
      });
      if (!mounted) return;
      setState(() {
        final rows = (result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        _rows = more ? [..._rows, ...rows] : rows;
        _cursor = result['cursor'] as String?;
        _failure = null;
      });
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (widget.load == null && widget.production && _filter == 'available') {
        final drafts = await RoyalCatalogRoyalClean.localDrafts();
        if (mounted) {
          setState(() {
            for (final d in drafts) {
              if (d['audited'] != true &&
                  '${d['id']}'.startsWith('n_') &&
                  !_rows.any((r) => r['id'] == d['id'])) {
                _rows.insert(0, {
                  'id': d['id'],
                  'title': d['product']['title'],
                  'code': d['product']['code'],
                  'audited': false,
                });
              }
            }
          });
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoyalCatalogEditorRoyalClean(id: id),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = normalizeProductSearchRoyalClean(_search.text);
    final rows = _rows
        .where(
          (r) => normalizeProductSearchRoyalClean(
            '${r['title']} ${r['code']} ${r['description'] ?? (r['source'] as Map?)?['description'] ?? ''}',
          ).contains(query),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071F2B),
        foregroundColor: Colors.white,
        title: Text(
          widget.production ? 'Produção · Auditoria' : 'Produtos · Vitrine',
        ),
        actions: [
          _control(
            'benefits',
            IconButton(
              tooltip: 'Convites de preço PJ',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RoyalPriceBenefitPageRoyalClean(),
                ),
              ),
              icon: const Icon(Icons.card_giftcard),
            ),
          ),
          _control(
            'refresh',
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.production
          ? _control(
              'create',
              FloatingActionButton.extended(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                onPressed: () => _edit('n_${RoyalCatalogRoyalClean.newId()}'),
                icon: const Icon(Icons.add),
                label: const Text('Criar produto'),
              ),
            )
          : null,
      body: _catalogBackground(
        enabled: widget.production,
        child: SafeArea(
          child: _auditGrid(
            rows,
            header: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.production
                        ? 'Escolha um produto do Bling ou crie um novo. Confira os dados e envie para Receitas.'
                        : 'Complete o cadastro em Receitas. Confira o estoque e publique na Nossa Vitrine.',
                    style: TextStyle(
                      color: widget.production ? Colors.white : _navy,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _control(
                              'filter.${e.key}',
                              ChoiceChip(
                                label: Text(e.value),
                                backgroundColor: Colors.white,
                                selectedColor: const Color(0xFF007F9F),
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _filter == e.key
                                      ? Colors.white
                                      : _navy,
                                ),
                                selected: _filter == e.key,
                                onSelected: _busy
                                    ? null
                                    : (_) {
                                        setState(() {
                                          _filter = e.key;
                                          _rows = [];
                                          _cursor = null;
                                        });
                                        _load();
                                      },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome, código ou descrição',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF007F9F)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_failure != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _failure!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _auditGrid(
    List<Map<String, dynamic>> rows, {
    required Widget header,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 36) / 2;
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      return CustomScrollView(
        slivers: [
          if (!widget.production)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: PreviewStorefrontRoyalClean(products: widget.storefront),
              ),
            ),
          SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent:
                    width + (widget.production ? 200 : 270) * textScale,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final row = rows[index];
                return CatalogAuditCardRoyalClean(
                  key: ValueKey('audit-product-${row['id']}'),
                  product: row,
                  production: widget.production,
                  onOpen: () => _edit('${row['id']}'),
                );
              }, childCount: rows.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              child: Column(
                children: [
                  if (rows.isEmpty && !_busy)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhum produto nesta página.',
                        style: TextStyle(
                          color: widget.production ? Colors.white : _navy,
                        ),
                      ),
                    ),
                  if (_cursor != null)
                    _control(
                      'more',
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _navy,
                        ),
                        onPressed: _busy ? null : () => _load(more: true),
                        child: const Text('Carregar próxima página'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class RoyalCatalogEditorRoyalClean extends StatefulWidget {
  final String id;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? call;
  final Future<Map<String, dynamic>?> Function()? readDraft;
  final Future<void> Function(Map<String, dynamic>)? saveDraft;
  final Future<void> Function()? clearDraft;
  const RoyalCatalogEditorRoyalClean({
    super.key,
    required this.id,
    this.call,
    this.readDraft,
    this.saveDraft,
    this.clearDraft,
  });
  @override
  State<RoyalCatalogEditorRoyalClean> createState() => _CatalogEditorState();
}

class _CatalogEditorState extends State<RoyalCatalogEditorRoyalClean>
    with WidgetsBindingObserver {
  final _fields = <String, TextEditingController>{};
  final _form = GlobalKey<FormState>();
  final _expandedSections = <String>{'identity'};
  final _sectionControllers = <String, ExpansibleController>{};
  Future<Map<String, dynamic>> _call(Map<String, dynamic> input) =>
      (widget.call ?? RoyalCatalogRoyalClean.call)(input);
  final _categories = <String>{}, _niches = <String>{};
  Map<String, dynamic>? _record;
  bool _busy = true,
      _box = false,
      _confirmed = false,
      _dirty = false,
      _ready = false;
  String? _failure, _notice;
  Timer? _debounce;
  Timer? _retryDraft;
  bool _foreground = true;
  int _draftRevision = 0;
  TextEditingController _f(String name) =>
      _fields.putIfAbsent(name, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _retryDraft = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_ready && _dirty && !_busy && _foreground) {
        unawaited(_saveDraft());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _retryDraft?.cancel();
    for (final controller in _sectionControllers.values) {
      controller.dispose();
    }
    if (_ready && _dirty) unawaited(_saveDraft());
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_ready && _dirty) {
      unawaited(_saveDraft());
    }
  }

  Future<void> _load() async {
    try {
      final localDraft =
          await (widget.readDraft?.call() ??
              RoyalCatalogRoyalClean.readDraft(widget.id));
      Map<String, dynamic> record;
      try {
        record = await _call({'action': 'get', 'id': widget.id});
      } catch (_) {
        if (localDraft == null) rethrow;
        record = {
          'id': widget.id,
          'revision': localDraft['revision'],
          'status': 'recipe',
          'audited': false,
        };
        _notice =
            'Sem conexão. Seu rascunho está disponível; a confirmação depende da conexão.';
      }
      final remoteDraft = record['draft'] is Map
          ? Map<String, dynamic>.from(record['draft'] as Map)
          : null;
      final draft = localDraft == null
          ? remoteDraft
          : remoteDraft == null
          ? localDraft
          : DateTime.parse(
              localDraft['savedAt'] as String,
            ).isAfter(DateTime.parse(remoteDraft['savedAt'] as String))
          ? localDraft
          : remoteDraft;
      if (!mounted) return;
      _record = record;
      _draftRevision = (draft?['revision'] ?? record['revision'] ?? 0) as int;
      final source = record['source'] as Map?;
      final product = draft?['product'] as Map? ?? record;
      final defaults = {
        'title': source?['name'],
        'code': source?['code'],
        'unit': source?['unit'],
      };
      for (final name in ['code', 'title', 'description', 'measure', 'unit']) {
        _f(name).text = '${product[name] ?? defaults[name] ?? ''}';
      }
      _f('reference').text =
          ((product['referenceCents'] as num?)?.toDouble().operatorDiv(100) ??
                  (source?['price'] as num?)?.toDouble() ??
                  0)
              .toStringAsFixed(2);
      _f('factor').text =
          ((product['factorMilli'] as num?)?.toDouble().operatorDiv(1000) ?? 1)
              .toString();
      _f('unitsPerBox').text = '${product['unitsPerBox'] ?? 1}';
      _f('threshold').text = '${product['threshold'] ?? 0}';
      final stock = product['initialStock'] as Map? ?? record['stock'] as Map?;
      _f('boxes').text = '${stock?['boxes'] ?? 0}';
      _f('loose').text = '${stock?['loose'] ?? 0}';
      _confirmed = stock?['confirmed'] == true;
      _categories.addAll((product['categories'] as List? ?? []).cast<String>());
      _niches.addAll((product['niches'] as List? ?? []).cast<String>());
      final presentations = product['presentations'] as List? ?? [];
      _box = presentations.any((p) => p['kind'] == 'box');
      for (final kind in ['unit', 'box']) {
        final p = presentations
            .cast<Map>()
            .where((v) => v['kind'] == kind)
            .firstOrNull;
        _f('$kind.image').text = '${p?['imageUrl'] ?? ''}';
        for (final price in ['cost', 'pf', 'pj', 'min']) {
          _f('$kind.$price').text = ((p?['${price}Cents'] as num? ?? 0) / 100)
              .toStringAsFixed(2);
        }
      }
      for (final controller in _fields.values) {
        controller.addListener(_changed);
      }
      _ready = true;
      if (draft != null) {
        _dirty = true;
        _notice = 'Rascunho recuperado. Revise antes de salvar.';
        if (_draftRevision != record['revision']) {
          _notice =
              'Há uma atualização mais recente em ${_when(record['updatedAt'])}, por ${record['updatedBy']}. Seu rascunho foi preservado. Revise e carregue a versão atual antes de salvar.';
        }
      }
    } catch (e) {
      _failure = _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed() {
    if (!_ready) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_saveDraft()),
    );
  }

  num _number(String name) =>
      num.tryParse(_f(name).text.replaceAll(',', '.')) ?? 0;
  Map<String, dynamic> _data() => {
    for (final name in ['code', 'title', 'description', 'measure', 'unit'])
      name: _f(name).text.trim(),
    'referenceCents': (_number('reference') * 100).round(),
    'factorMilli': (_number('factor') * 1000).round(),
    'unitsPerBox': _number('unitsPerBox').toInt(),
    'threshold': _number('threshold').toInt(),
    'categories': _categories.toList(),
    'niches': _niches.toList(),
    'initialStock': {
      'boxes': _number('boxes').toInt(),
      'loose': _number('loose').toInt(),
      'confirmed': _confirmed,
    },
    'presentations': [
      for (final kind in ['unit', if (_box) 'box'])
        {
          'kind': kind,
          'imageUrl': _f('$kind.image').text.trim(),
          for (final price in ['cost', 'pf', 'pj', 'min'])
            '${price}Cents': (_number('$kind.$price') * 100).round(),
        },
    ],
  };
  Future<void> _saveDraft() async {
    final data = {
      'revision': _draftRevision,
      'product': _data(),
      'savedAt': DateTime.now().toIso8601String(),
      'audited': _record?['audited'] == true,
    };
    try {
      await (widget.saveDraft?.call(data) ??
          RoyalCatalogRoyalClean.draft(widget.id, data));
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'Não foi possível guardar o rascunho neste dispositivo. Salve antes de sair.',
        );
      }
    }
  }

  Future<void> _submit(String action) async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      setState(
        () => _expandedSections.addAll([
          'identity',
          'stock',
          'presentation.unit',
          'presentation.box',
          'placement',
        ]),
      );
      for (final id in _expandedSections) {
        _sectionControllers[id]?.expand();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revise os campos destacados antes de continuar.'),
        ),
      );
      return;
    }
    _debounce?.cancel();
    setState(() => _busy = true);
    await _saveDraft();
    if (!mounted) return;
    final data = _data();
    final conversionChanged =
        _record?['audited'] == true &&
        (data['unitsPerBox'] != _record!['unitsPerBox'] ||
            data['factorMilli'] != _record!['factorMilli']);
    if (conversionChanged) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar nova embalagem ou conversao?'),
          content: const Text(
            'Confira a referencia original e o saldo fisico. Alterar unidades por caixa exige saldo zerado e nenhuma devolucao pendente.',
          ),
          actions: [
            _control(
              'conversion.cancel',
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Revisar'),
              ),
            ),
            _control(
              'conversion.confirm',
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Conferi a conversao'),
              ),
            ),
          ],
        ),
      );
      if (yes != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
    }
    if (action == 'publish') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publicar na Nossa Vitrine?'),
          content: const Text(
            'Confirme as fotos, preços, categorias e estoque. As apresentações usarão o mesmo saldo físico.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar publicação'),
            ),
          ],
        ),
      );
      if (yes != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _call({
        'action': action,
        'id': widget.id,
        'revision': _draftRevision,
        'requestId': RoyalCatalogRoyalClean.newId(),
        'product': data,
        'confirmConversion': conversionChanged,
      });
      await (widget.clearDraft?.call() ??
          RoyalCatalogRoyalClean.clearDraft(widget.id));
      _dirty = false;
      if (mounted) {
        setState(() {
          _record = result;
          _draftRevision = result['revision'] as int;
          _notice = action == 'publish'
              ? 'Publicado na Nossa Vitrine.'
              : 'Cadastro salvo. ${result['status'] == 'recipe' ? 'Disponível em Receitas.' : 'Alterações confirmadas.'}';
          _failure = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'publish'
                  ? 'Publicado na Nossa Vitrine.'
                  : 'Cadastro salvo com sucesso.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _failure = e is FirebaseFunctionsException && e.code == 'aborted'
              ? '${_error(e)}\nÚltima atualização: ${_when((e.details as Map?)?['updatedAt'])}\nResponsável: ${(e.details as Map?)?['updatedBy'] ?? ''}. Seu rascunho está preservado.'
              : _error(e),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error(e)),
            action: e is FirebaseFunctionsException && e.code == 'aborted'
                ? SnackBarAction(label: 'Revisar', onPressed: _reviewConflict)
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewConflict() async {
    try {
      final latest = await _call({'action': 'get', 'id': widget.id});
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Revisar atualização mais recente'),
          content: SingleChildScrollView(
            child: Text(
              'Atualizado em ${_when(latest['updatedAt'])}\nResponsável: ${latest['updatedBy']}\nTítulo: ${latest['title']}\nMedida: ${latest['measure']}\nUnidades por caixa: ${latest['unitsPerBox']}\nPreços: ${latest['presentations']}\n\nSeu rascunho continua no formulário. Confira as diferenças antes de confirmar o salvamento. O saldo atualizado será preservado.',
            ),
          ),
          actions: [
            _control(
              'conflict.cancel',
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Voltar'),
              ),
            ),
            _control(
              'conflict.reviewed',
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Revisei · continuar edição'),
              ),
            ),
          ],
        ),
      );
      if (yes == true && mounted) {
        setState(() {
          _record = latest;
          _draftRevision = latest['revision'] as int;
          _failure = null;
          _notice =
              'Versão atual revisada. Confirme suas alterações quando terminar.';
        });
        _changed();
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    }
  }

  Future<void> _photo(String kind) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw StateError('Foto muito grande');
      if (!mounted) return;
      setState(() => _busy = true);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance.ref(
        'catalog_media/$uid/${widget.id}/${RoyalCatalogRoyalClean.newId()}.jpg',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      _f('$kind.image').text = await ref.getDownloadURL();
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure =
              'Não foi possível enviar a foto. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String name,
    String label, {
    bool number = false,
    bool required = false,
    bool integer = false,
    bool enabled = true,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: TextFormField(
      controller: _f(name),
      enabled: enabled && !_busy,
      maxLines: lines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0x66020C20),
        isDense: true,
        helperText: name == 'factor'
            ? 'Ex.: 1,60 na NF-e corresponde a 1 bobina.'
            : null,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (required && (v ?? '').trim().isEmpty) return 'Preencha este campo';
        if (number) {
          final raw = (v ?? '').trim();
          if (name == 'factor' &&
              !RegExp(r'^\d+(?:[.,]\d{1,3})?$').hasMatch(raw)) {
            return 'Use até três casas decimais, sem arredondar';
          }
          if (!integer &&
              name != 'factor' &&
              !RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(raw)) {
            return 'Use até duas casas decimais';
          }
          final n = num.tryParse((v ?? '').replaceAll(',', '.'));
          if (n == null ||
              !n.isFinite ||
              n < 0 ||
              (integer && n != n.roundToDouble())) {
            return integer
                ? 'Informe uma quantidade inteira'
                : 'Informe um valor válido';
          }
        }
        return null;
      },
    ),
  );
  Widget _section(
    String title,
    List<Widget> children, {
    Color titleColor = const Color(0xFFABD4ED),
    required String sectionId,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: NfePanelRoyalClean(
      child: _control(
        'editor.section.$sectionId',
        ExpansionTile(
          key: ValueKey('editor-section-$sectionId'),
          controller: _sectionControllers.putIfAbsent(
            sectionId,
            ExpansibleController.new,
          ),
          initiallyExpanded: _expandedSections.contains(sectionId),
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (open) {
            if (open) {
              _expandedSections.add(sectionId);
            } else {
              _expandedSections.remove(sectionId);
            }
          },
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ],
        ),
      ),
    ),
  );
  Widget _priceFields(String kind) => LayoutBuilder(
    builder: (context, constraints) {
      final fields = [
        _field('$kind.cost', 'Compra (R\$)', number: true),
        _field('$kind.min', 'Mínimo (R\$)', number: true),
        _field('$kind.pf', 'Venda PF (R\$)', number: true),
        _field('$kind.pj', 'Venda PJ (R\$)', number: true),
      ];
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(children: fields);
      }
      return Column(
        children: [
          for (var i = 0; i < fields.length; i += 2)
            Row(
              children: [
                Expanded(child: fields[i]),
                const SizedBox(width: 10),
                Expanded(child: fields[i + 1]),
              ],
            ),
        ],
      );
    },
  );

  Widget _photoPreview(String kind, {double size = 150}) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _f('$kind.image'),
        builder: (_, value, _) => SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CatalogAuditImageRoyalClean(
              product: {
                'audited': true,
                'presentations': [
                  {'imageUrl': value.text.trim()},
                ],
              },
            ),
          ),
        ),
      );

  Widget _productSheet() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: NfePanelRoyalClean(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Prévia da imagem do produto',
            child: _photoPreview('unit', size: 90),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FICHA DO PRODUTO',
                  style: TextStyle(
                    color: Color(0xFFABD4ED),
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _f('title'),
                  builder: (_, value, _) => Text(
                    value.text.trim().isEmpty ? 'Novo produto' : value.text,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _record?['archived'] == true
                      ? 'Arquivado'
                      : {
                              'published': 'Publicado',
                              'suspended': 'Suspenso',
                              'recipe': 'Receitas',
                            }[_record?['status']] ??
                            'Em auditoria',
                  style: const TextStyle(
                    color: Color(0xFFABD4ED),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Rascunho automático. Confirme para aplicar.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _saveActions() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _control(
              'save',
              OutlinedButton(
                onPressed: _busy || !_ready || _record?['archived'] == true
                    ? null
                    : () => _submit('save'),
                child: Text(
                  _record?['audited'] == true
                      ? 'Salvar alterações'
                      : 'Salvar em Receitas',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _control(
              'publish',
              FilledButton(
                onPressed: _busy || !_ready || _record?['archived'] == true
                    ? null
                    : () => _submit('publish'),
                child: const Text(
                  'Publicar na vitrine',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _history() async {
    try {
      final result = await _call({'action': 'history', 'id': widget.id});
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: ListView(
              children: [
                const ListTile(title: Text('Histórico do produto')),
                for (final event in result['items'] as List)
                  ListTile(
                    title: Text(
                      '${{'save': 'Cadastro atualizado', 'publish': 'Publicado', 'suspend': 'Suspenso', 'archive': 'Arquivado', 'restore': 'Restaurado', 'stock': 'Estoque movimentado'}[event['action']] ?? event['action']} · ${_when(event['at'])}',
                    ),
                    subtitle: Text(
                      'Responsável: ${event['by']}\n${event['reason'] ?? ''}\n${(event['prices'] as List).map((p) => '${p['kind'] == 'box' ? 'Caixa' : 'Unidade'} · custo ${catalogMoneyRoyalClean(p['costCents'])} · PF ${catalogMoneyRoyalClean(p['pfCents'])} · PJ ${catalogMoneyRoyalClean(p['pjCents'])}').join('\n')}${event['movement'] != null ? '\nSaldo anterior: ${event['movement']['before']['boxes']} caixas, ${event['movement']['before']['loose']} avulsas\nNovo saldo: ${event['movement']['after']['boxes']} caixas, ${event['movement']['after']['loose']} avulsas' : ''}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    }
  }

  Future<void> _historicalPrices() async {
    try {
      final result = await _call({'action': 'history', 'id': widget.id});
      if (!mounted) return;
      final event = await showModalBottomSheet<Map>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text('Escolher preços registrados'),
                subtitle: Text(
                  'A escolha preenche o rascunho. Revise e salve para aplicar.',
                ),
              ),
              for (final e in result['items'] as List)
                _control(
                  'price.history.${e['id']}',
                  ListTile(
                    title: Text(_when(e['at'])),
                    subtitle: Text(
                      (e['prices'] as List)
                          .map(
                            (p) =>
                                '${p['kind'] == 'box' ? 'Caixa' : 'Unidade'} · custo ${catalogMoneyRoyalClean(p['costCents'])} · PF ${catalogMoneyRoyalClean(p['pfCents'])} · PJ ${catalogMoneyRoyalClean(p['pjCents'])}',
                          )
                          .join('\n'),
                    ),
                    onTap: () => Navigator.pop(context, e as Map),
                  ),
                ),
            ],
          ),
        ),
      );
      if (event != null && mounted) {
        setState(() {
          for (final p in event['prices'] as List) {
            for (final key in ['cost', 'pf', 'pj', 'min']) {
              _f('${p['kind']}.$key').text = ((p['${key}Cents'] as num) / 100)
                  .toStringAsFixed(2);
            }
          }
          _notice =
              'Preços históricos carregados no rascunho. Revise antes de salvar.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    }
  }

  Future<void> _stock() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _StockMovementPage(record: _record!)),
    );
    if (changed == true && mounted) {
      for (final f in _fields.values) {
        f.removeListener(_changed);
      }
      _ready = false;
      _categories.clear();
      _niches.clear();
      setState(() => _busy = true);
      await _load();
    }
  }

  Future<void> _status(String action) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'restore'
              ? 'Restaurar para Receitas?'
              : action == 'archive'
              ? 'Arquivar este produto?'
              : 'Suspender este produto?',
        ),
        content: Text(
          action == 'restore'
              ? 'O cadastro e o saldo serão preservados. Revise a auditoria antes de publicar novamente.'
              : 'O produto será ocultado da vitrine. Seu histórico será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final result = await _call({
        'action': action,
        'id': widget.id,
        'revision': _record!['revision'],
        'requestId': RoyalCatalogRoyalClean.newId(),
      });
      if (mounted) {
        if (action == 'archive' || action == 'restore') {
          _dirty = false;
          await (widget.clearDraft?.call() ??
              RoyalCatalogRoyalClean.clearDraft(widget.id));
          if (!mounted) return;
          Navigator.pop(context);
        } else {
          setState(() => _record = result);
          _draftRevision = result['revision'] as int;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF25BFFF),
        brightness: Brightness.dark,
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: Color(0xFFBCD7EF)),
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF020C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071F2B),
        foregroundColor: Colors.white,
        title: const Text('Cadastro do produto'),
        actions: [
          if (_record?['audited'] == true)
            _control(
              'history',
              IconButton(
                onPressed: _history,
                tooltip: 'Histórico',
                icon: const Icon(Icons.history),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _saveActions(),
      body: _catalogBackground(
        child: !_ready
            ? Center(
                child: _busy
                    ? const CircularProgressIndicator()
                    : Text(_failure ?? 'Não foi possível carregar.'),
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Form(
                      key: _form,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _productSheet(),
                            if (_busy) const LinearProgressIndicator(),
                            if (_notice != null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(_notice!),
                                ),
                              ),
                            if (_failure != null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _failure!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            if (_record?['audited'] == true)
                              _control(
                                'conflict.review',
                                OutlinedButton(
                                  onPressed: _busy ? null : _reviewConflict,
                                  child: const Text(
                                    'Revisar versão mais recente',
                                  ),
                                ),
                              ),
                            if (_record?['source'] != null)
                              _section(
                                'Ultimo Lançe',
                                [
                                  Text(
                                    'Nome: ${_record!['source']['name']}\nCódigo: ${_record!['source']['code']}\nPreço original: ${catalogMoneyRoyalClean(((_record!['source']['price'] as num? ?? 0) * 100).round())}\nUnidade original: ${_record!['source']['unit']}',
                                  ),
                                  const Text(
                                    'Esta referência é preservada. A edição abaixo pertence ao Royal Clean.',
                                  ),
                                ],
                                titleColor: const Color(0xFFFFB6C1),
                                sectionId: 'source',
                              ),
                            _section('1. Identificação e auditoria', [
                              _field(
                                'code',
                                'Código / identificação',
                                required: true,
                              ),
                              _field(
                                'title',
                                'Título do produto',
                                required: true,
                              ),
                              _field(
                                'reference',
                                'Preço de referência da auditoria (R\$)',
                                number: true,
                                required: true,
                              ),
                              _field(
                                'measure',
                                'Medida / capacidade',
                                required: true,
                              ),
                              _field(
                                'unit',
                                'Unidade de venda',
                                required: true,
                              ),
                              _field(
                                'factor',
                                'Quantidade na NF-e equivalente a 1 unidade',
                                number: true,
                                required: true,
                              ),
                              _control(
                                'convert',
                                OutlinedButton(
                                  onPressed: _busy ? null : _conversion,
                                  child: const Text(
                                    'Conferir conversão da NF-e',
                                  ),
                                ),
                              ),
                              _field(
                                'description',
                                'Descrição para o cliente',
                                lines: 4,
                              ),
                              _control(
                                'source.invoices',
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const BlingDataPageRoyalClean(
                                            initialKind: 'invoices',
                                          ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text(
                                    'Consultar referência original da NF-e',
                                  ),
                                ),
                              ),
                            ], sectionId: 'identity'),
                            _section('2. Embalagem e estoque', [
                              if (_record?['lastCostCents'] != null)
                                Text(
                                  'Último custo de entrada por unidade: ${catalogMoneyRoyalClean(_record!['lastCostCents'])}. Os preços de venda permanecem até sua confirmação.',
                                ),
                              _field(
                                'unitsPerBox',
                                'Unidades em cada caixa / pacote',
                                number: true,
                                integer: true,
                                required: true,
                              ),
                              _field(
                                'boxes',
                                'Caixas / pacotes fechados',
                                number: true,
                                integer: true,
                                enabled:
                                    _record?['stock']?['confirmed'] != true,
                              ),
                              _field(
                                'loose',
                                'Unidades avulsas',
                                number: true,
                                integer: true,
                                enabled:
                                    _record?['stock']?['confirmed'] != true,
                              ),
                              _field(
                                'threshold',
                                'Limite para Observação (unidades)',
                                number: true,
                                integer: true,
                              ),
                              _control(
                                'stock.confirm',
                                CheckboxListTile(
                                  value: _confirmed,
                                  onChanged:
                                      _record?['stock']?['confirmed'] == true
                                      ? null
                                      : (v) {
                                          setState(
                                            () => _confirmed = v ?? false,
                                          );
                                          _changed();
                                        },
                                  title: const Text(
                                    'Conferi o estoque inicial',
                                  ),
                                ),
                              ),
                              if (_record?['stock']?['confirmed'] == true)
                                _control(
                                  'movement',
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _stock,
                                    icon: const Icon(Icons.swap_vert),
                                    label: const Text(
                                      'Registrar entrada, saída ou conferência',
                                    ),
                                  ),
                                ),
                              _control(
                                'box.enabled',
                                SwitchListTile(
                                  value: _box,
                                  onChanged: _busy
                                      ? null
                                      : (v) {
                                          setState(() => _box = v);
                                          _changed();
                                        },
                                  title: const Text(
                                    'Também vender caixa / pacote',
                                  ),
                                  subtitle: const Text(
                                    'As apresentações compartilham a mesma mercadoria.',
                                  ),
                                ),
                              ),
                            ], sectionId: 'stock'),
                            for (final kind in ['unit', if (_box) 'box'])
                              _section(
                                kind == 'unit'
                                    ? '3. Apresentação · Unidade'
                                    : 'Apresentação · Caixa / pacote',
                                [
                                  Center(child: _photoPreview(kind)),
                                  _field(
                                    '$kind.image',
                                    'Foto principal · endereço HTTPS',
                                  ),
                                  _control(
                                    'photo.$kind',
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _photo(kind),
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text('Atualizar foto'),
                                    ),
                                  ),
                                  if (kind == 'box')
                                    _control(
                                      'photo.reuse',
                                      TextButton(
                                        onPressed: () {
                                          setState(
                                            () => _f('box.image').text = _f(
                                              'unit.image',
                                            ).text,
                                          );
                                        },
                                        child: const Text(
                                          'Reutilizar foto da unidade',
                                        ),
                                      ),
                                    ),
                                  const Text(
                                    'PF: varejo · PJ: CNPJ · Mínimo: negociação',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFABD4ED),
                                    ),
                                  ),
                                  _priceFields(kind),
                                ],
                                sectionId: 'presentation.$kind',
                              ),
                            _section('4. Onde aparecer na vitrine', [
                              const Text('Categorias'),
                              Wrap(
                                spacing: 6,
                                children: productCategoriesRoyalClean
                                    .map(
                                      (c) => _control(
                                        'category.${c.id}',
                                        FilterChip(
                                          label: Text(c.title),
                                          selected: _categories.contains(c.id),
                                          onSelected: _busy
                                              ? null
                                              : (v) {
                                                  setState(
                                                    () => v
                                                        ? _categories.add(c.id)
                                                        : _categories.remove(
                                                            c.id,
                                                          ),
                                                  );
                                                  _changed();
                                                },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              const Text('Nichos'),
                              Wrap(
                                spacing: 6,
                                children: productNichesRoyalClean
                                    .where((n) => n != 'Todos')
                                    .map(
                                      (n) => _control(
                                        'niche.$n',
                                        FilterChip(
                                          label: Text(n),
                                          selected: _niches.contains(n),
                                          onSelected: _busy
                                              ? null
                                              : (v) {
                                                  setState(
                                                    () => v
                                                        ? _niches.add(n)
                                                        : _niches.remove(n),
                                                  );
                                                  _changed();
                                                },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ], sectionId: 'placement'),
                            _section('Ações administrativas', [
                              if (_record?['audited'] == true)
                                _control(
                                  'prices.history',
                                  OutlinedButton(
                                    onPressed: _busy ? null : _historicalPrices,
                                    child: const Text(
                                      'Carregar preços do histórico no rascunho',
                                    ),
                                  ),
                                ),
                              if (_record?['archived'] == true)
                                _control(
                                  'restore',
                                  FilledButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _status('restore'),
                                    child: const Text(
                                      'Restaurar cadastro para Receitas',
                                    ),
                                  ),
                                ),
                              if (_record?['audited'] == true &&
                                  _record?['archived'] != true) ...[
                                _control(
                                  'suspend',
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _status('suspend'),
                                    child: const Text(
                                      'Suspender · ocultar da vitrine',
                                    ),
                                  ),
                                ),
                                _control(
                                  'archive',
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _status('archive'),
                                    child: const Text('Arquivar produto'),
                                  ),
                                ),
                              ],
                            ], sectionId: 'management'),
                            Text(
                              'Última atualização: ${_when(_record?['updatedAt'])}\nResponsável: ${_record?['updatedBy'] ?? '—'}\nRascunho automático neste dispositivo. A vitrine muda somente após confirmação.',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
  Future<void> _conversion() async {
    final quantity = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferir quantidade da NF-e'),
        content: TextField(
          controller: quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantidade original da NF-e',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final q = num.tryParse(quantity.text.replaceAll(',', '.'));
              final f = _number('factor');
              if (q == null ||
                  f <= 0 ||
                  !RegExp(
                    r'^\d+(?:[.,]\d{1,3})?$',
                  ).hasMatch(quantity.text.trim())) {
                return;
              }
              final numerator = (q * 1000).round(),
                  denominator = (f * 1000).round();
              if (denominator <= 0) return;
              final exact = numerator % denominator == 0;
              Navigator.pop(context);
              setState(
                () => _notice = exact
                    ? '${quantity.text} na NF-e = ${numerator ~/ denominator} ${_f('unit').text}(s). Nenhum saldo foi alterado.'
                    : 'Quantidade incompatível com unidades inteiras. Confira a referência original da NF-e. Nenhum saldo foi alterado.',
              );
            },
            child: const Text('Conferir'),
          ),
        ],
      ),
    );
    quantity.dispose();
  }
}

extension on double {
  double operatorDiv(double value) => this / value;
}

class _StockMovementPage extends StatefulWidget {
  final Map<String, dynamic> record;
  const _StockMovementPage({required this.record});
  @override
  State<_StockMovementPage> createState() => _StockMovementState();
}

class _StockMovementState extends State<_StockMovementPage> {
  final _boxes = TextEditingController(text: '0'),
      _loose = TextEditingController(text: '0'),
      _reason = TextEditingController(),
      _cost = TextEditingController();
  String _type = 'entry';
  bool _busy = false;
  String? _failure;
  final _types = {
    'entry': 'Entrada / reposição',
    'open': 'Abrir caixa / pacote',
    'exit': 'Saída confirmada',
    'return': 'Devolução / retorno · aguarda conferência',
    'release': 'Conferir retorno · liberar estoque',
    'loss': 'Perda',
    'adjust': 'Ajustar contagem física',
  };
  @override
  void dispose() {
    for (final c in [_boxes, _loose, _reason, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final boxes = int.tryParse(_boxes.text), loose = int.tryParse(_loose.text);
    if (boxes == null ||
        loose == null ||
        boxes < 0 ||
        loose < 0 ||
        _reason.text.trim().length < 3) {
      setState(() => _failure = 'Informe quantidades inteiras e o motivo.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar movimentação?'),
        content: Text(
          '${_types[_type]}\n$boxes caixas e $loose unidades\n${_reason.text}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await RoyalCatalogRoyalClean.call({
        'action': 'stock',
        'id': widget.record['id'],
        'revision': widget.record['revision'],
        'requestId': RoyalCatalogRoyalClean.newId(),
        'type': _type,
        'boxes': boxes,
        'loose': loose,
        'reason': _reason.text.trim(),
        if (_type == 'entry' && _cost.text.isNotEmpty)
          'costCents': catalogCentsRoyalClean(_cost.text),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF071F2B),
      foregroundColor: Colors.white,
      title: const Text('Movimentar estoque'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${widget.record['title']}\nSaldo: ${widget.record['stock']['boxes']} caixas · ${widget.record['stock']['loose']} avulsas\nAguardando conferência: ${widget.record['stock']['held'] ?? 0} unidades',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _type,
          items: _types.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: _busy ? null : (v) => setState(() => _type = v!),
          decoration: const InputDecoration(labelText: 'Operação'),
        ),
        for (final entry in {
          'Caixas / pacotes': _boxes,
          'Unidades avulsas': _loose,
          'Motivo / referência do pedido': _reason,
        }.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: TextField(
              controller: entry.value,
              decoration: InputDecoration(
                labelText: entry.key,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        if (_type == 'entry')
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Custo de compra por unidade (R\$) · opcional',
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Abrir caixas mantém a quantidade total. Devoluções aguardam conferência. Cada operação é registrada com responsável, data e motivo. Ajustar contagem define o novo saldo físico.',
          ),
        ),
        if (_failure != null)
          Text(_failure!, style: const TextStyle(color: Colors.red)),
        _control(
          'stock.save',
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Salvando…' : 'Confirmar movimentação'),
          ),
        ),
      ],
    ),
  );
}
