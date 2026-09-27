import 'dart:async';
import '../../core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';

typedef ContactLoaderRoyalClean =
    Future<Map<String, dynamic>> Function(Map<String, dynamic>);

Future<Map<String, dynamic>> _loadContact(Map<String, dynamic> query) async {
  final result =
      await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable(
            'blingReadData',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 55)),
          )
          .call(query);
  return Map<String, dynamic>.from(result.data as Map);
}

String _errorText(Object error) {
  if (error is FirebaseFunctionsException) {
    if (error.code == 'unauthenticated') {
      return 'Não foi possível validar o acesso. Verifique sua sessão e tente novamente.';
    }
    return error.message ?? 'Consulta indisponível. Tente novamente.';
  }
  return 'Não foi possível consultar os contatos. Verifique a conexão e tente novamente.';
}

Widget _adminPage(Widget child, ContactLoaderRoyalClean? load) => load != null
    ? child
    : AdminRouteGuardRoyalClean(
        firebaseInitialization: Future<void>.value(),
        builder: (_) => child,
      );

Future<void> openActiveContactsRoyalClean(
  BuildContext context,
  String role, {
  ContactLoaderRoyalClean? load,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) =>
        _adminPage(ActiveContactsPageRoyalClean(role: role, load: load), load),
  ),
);

class ActiveContactsPageRoyalClean extends StatefulWidget {
  final String role;
  final ContactLoaderRoyalClean? load;
  final ActiveContactsCacheRoyalClean? cache;
  const ActiveContactsPageRoyalClean({
    super.key,
    required this.role,
    this.load,
    this.cache,
  });
  @override
  State<ActiveContactsPageRoyalClean> createState() => _ActiveContactsState();
}

class _ActiveContactsState extends State<ActiveContactsPageRoyalClean> {
  ActiveContactsCacheRoyalClean? _cache;
  int _visibleCount = 25;
  final _items = <Map<String, dynamic>>[];
  bool _busy = false, _hasMore = false;
  int _page = 0, _total = 0;
  String? _run, _error, _checked;
  final _scroll = ScrollController();
  String get _roleLabel =>
      const {
        'all': 'Todos',
        'customer': 'Clientes',
        'supplier': 'Fornecedores',
        'unclassified': 'Sem classificação',
      }[widget.role] ??
      'Todos';
  @override
  void initState() {
    super.initState();
    _cache =
        widget.cache ??
        (widget.load == null
            ? ActiveContactsSessionRoyalClean.instance.cache
            : null);
    if (_cache != null) {
      if (widget.cache == null) {
        ActiveContactsSessionRoyalClean.instance.start();
      }
      _cache!.addListener(_cachedChanged);
      _applyCache();
      unawaited(_cache!.refresh());
    } else {
      _fetch(reset: true);
    }
  }

  @override
  void dispose() {
    _cache?.removeListener(_cachedChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _applyCache() {
    final cache = _cache!;
    final rows = cache.rows(widget.role);
    _items
      ..clear()
      ..addAll(rows.take(_visibleCount));
    _total = rows.length;
    _hasMore = rows.length > _visibleCount;
    _busy = cache.busy;
    _checked = cache.checkedAt;
    _error = cache.error == null
        ? null
        : cache.hasData
        ? 'Última lista preservada. Não foi possível atualizar. Tente novamente.'
        : _errorText(cache.error!);
  }

  void _cachedChanged() {
    if (mounted) setState(_applyCache);
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_cache != null) {
      if (reset) {
        await _cache!.refresh(force: true);
      } else {
        setState(() {
          _visibleCount += 25;
          _applyCache();
        });
      }
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = reset ? 1 : _page + 1;
      final data = await (widget.load ?? _loadContact)({
        'kind': 'activeContacts',
        'contactRole': widget.role,
        'page': next,
        if (!reset && _run != null) 'catalogRun': _run,
      });
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(
          (data['items'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        _page = next;
        _total = (data['total'] as num).toInt();
        _hasMore = data['hasMore'] == true;
        _run = data['catalogRun'] as String?;
        _checked = data['checkedAt'] as String?;
      });
      if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _details(Map<String, dynamic> item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _adminPage(
          ContactDetailsPageRoyalClean(
            id: item['id'] as String,
            name: item['name'] as String? ?? 'Contato',
            load: widget.load,
          ),
          widget.load,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      title: const Text('Contatos ativos'),
      actions: [
        IconButton(
          tooltip: 'Atualizar lista',
          onPressed: _busy ? null : () => _fetch(reset: true),
          icon: const Icon(Icons.refresh),
        ),
        const HeaderActionsRoyalClean(),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_total contatos ativos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pressione e segure um contato para consultar seu cadastro no Bling.',
                ),
                if (_checked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Base sincronizada • ${_date(_checked!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () => _fetch(reset: true),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _items.isEmpty && !_busy && _error == null
                ? const Center(
                    child: Text('Nenhum contato ativo nesta categoria.'),
                  )
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return OutlinedButton(
                          onPressed: _busy ? null : () => _fetch(),
                          child: const Text('Carregar mais contatos'),
                        );
                      }
                      final item = _items[index],
                          name = (item['name'] as String? ?? '').trim();
                      final code = item['code'] as String? ?? '';
                      return Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: ValueKey('contact-${item['id']}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            child: Icon(
                              (item['document'] as String? ?? '')
                                          .replaceAll(RegExp(r'\D'), '')
                                          .length ==
                                      14
                                  ? Icons.business_rounded
                                  : Icons.person_outline,
                            ),
                          ),
                          title: Text(
                            name.isEmpty ? 'Contato ${item['id']}' : name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${code.isEmpty ? 'ID Bling ${item['id']}' : 'Código $code'}\n${item['document'] ?? ''}',
                            ),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Ver cadastro',
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () => _details(item),
                          ),
                          onLongPress: () => _details(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

String _date(String raw) {
  final d = DateTime.tryParse(raw)?.toLocal();
  if (d == null) return 'Data não informada';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} às ${two(d.hour)}:${two(d.minute)}';
}

class ContactDetailsPageRoyalClean extends StatefulWidget {
  final String id, name;
  final ContactLoaderRoyalClean? load;
  const ContactDetailsPageRoyalClean({
    super.key,
    required this.id,
    required this.name,
    this.load,
  });
  @override
  State<ContactDetailsPageRoyalClean> createState() => _ContactDetailsState();
}

class _ContactDetailsState extends State<ContactDetailsPageRoyalClean> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await (widget.load ?? _loadContact)({
        'kind': 'contactDetails',
        'contactId': widget.id,
      });
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cadastro do contato'),
      actions: const [HeaderActionsRoyalClean()],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _data?['name'] as String? ?? widget.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('ID Bling ${widget.id} • Somente consulta'),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _fetch,
              child: const Text('Tentar novamente'),
            ),
          ],
          if (_data != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Consultado diretamente no Bling • ${_date(_data!['checkedAt'] as String)}',
              ),
            ),
            for (final section in _data!['sections'] as List)
              Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        section['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      if ((section['fields'] as List).isEmpty)
                        const Text('Não informado no Bling.'),
                      for (final field in section['fields'] as List)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                field['label'] as String,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 3),
                              SelectableText(
                                (field['value'] as String).isEmpty
                                    ? 'Não informado'
                                    : field['value'] as String,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
