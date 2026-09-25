import 'dart:math' as math;
import 'package:flutter/material.dart';

const productNichesRoyalClean = [
  'Todos',
  'Lançamentos',
  'Ofertas',
  'Dia a dia',
  'Kits',
  'Básicos',
];

String normalizeProductSearchRoyalClean(String value) {
  const accented = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  var result = value.toLowerCase().trim();
  for (var i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], plain[i]);
  }
  return result;
}

class ProductFiltersRoyalClean extends StatefulWidget {
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onSearch;
  const ProductFiltersRoyalClean({
    super.key,
    required this.onCategory,
    required this.onSearch,
  });
  @override
  State<ProductFiltersRoyalClean> createState() =>
      _ProductFiltersRoyalCleanState();
}

class _ProductFiltersRoyalCleanState extends State<ProductFiltersRoyalClean> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _nicheScroll = ScrollController();
  bool _search = false;
  bool _expanded = false;
  String _selected = 'Todos';

  void _toggleSearch() {
    setState(() {
      _search = !_search;
      _expanded = false;
      _selected = 'Todos';
    });
    _controller.clear();
    widget.onSearch('');
    widget.onCategory('Todos');
    if (_search) {
      _focus.requestFocus();
    } else {
      _focus.unfocus();
    }
  }

  void _submitSearch() {
    widget.onSearch(_controller.text.trim());
    _focus.unfocus();
  }

  void _onSearchIcon() {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    if (!_search || _controller.text.trim().isEmpty) {
      _toggleSearch();
    } else {
      _submitSearch();
    }
  }

  void _scrollNiches() {
    if (!_nicheScroll.hasClients) return;
    final position = _nicheScroll.position;
    final next = position.pixels >= position.maxScrollExtent - 1
        ? 0.0
        : math.min(
            position.maxScrollExtent,
            position.pixels + position.viewportDimension * .75,
          );
    _nicheScroll.animateTo(
      next,
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 350,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _nicheScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Pesquisar produtos',
        onPressed: _onSearchIcon,
        icon: const Icon(Icons.search_rounded),
        color: const Color(0xFF092F43),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: _search
            ? TextField(
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                style: const TextStyle(color: Color(0xFF092F43), fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Nome, código ou tags',
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: const TextStyle(
                    color: Color(0xFF607783),
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Fechar pesquisa',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _toggleSearch,
                  ),
                ),
              )
            : !_expanded
            ? Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFDCE5EA)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _toggleSearch,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    child: Text(
                      'Nome, código ou tags',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xFF607783), fontSize: 13),
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                controller: _nicheScroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_expanded) ...[
                      const SizedBox(width: 8),
                      for (final niche in productNichesRoyalClean)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(niche),
                            selected: niche == _selected,
                            showCheckmark: false,
                            selectedColor: const Color(0xFF092F43),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: niche == _selected
                                  ? Colors.white
                                  : const Color(0xFF607783),
                            ),
                            onSelected: (_) {
                              setState(() => _selected = niche);
                              widget.onCategory(niche);
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
      if (_expanded && !_search)
        IconButton(
          tooltip: 'Rolar a lista de nichos',
          onPressed: _scrollNiches,
          icon: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 1600,
            ),
            builder: (context, value, child) => Transform.translate(
              offset: Offset(math.sin(value * math.pi * 4) * 4, 0),
              child: child,
            ),
            child: const Icon(
              Icons.keyboard_double_arrow_right_rounded,
              color: Color(0xFF007F9F),
            ),
          ),
        ),
      if (!_search && !_expanded) ...[
        const SizedBox(width: 8),
        ActionChip(
          label: const Text('Nichos'),
          avatar: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
      ],
    ],
  );
}
