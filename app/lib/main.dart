// lib/main.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'pages/datastory_ttr.dart';
import 'pages/ai_adapter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

// EAIS Prototype — Vibrant redesign (finalized)
// Single-file demo with product_data.json-driven dynamics and inline raw-data card.

void main() {
  runApp(const EaisVibrantApp());
}

// Palette
const Color kBlue1 = Color(0xFF0B5ED7);
const Color kBlue2 = Color(0xFF1e90ff);
const Color kAccent = Color(0xFF00C2A8);
const Color kCard = Color(0xFFFAFBFF);

class EaisVibrantApp extends StatelessWidget {
  const EaisVibrantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: kBlue1, secondary: kAccent);

    return MaterialApp(
      title: 'ЕАИС — прототип (вибрантный)',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: Typography.blackMountainView,
      ),
      home: const HomePageVibrant(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ---------------- Home page ----------------

class HomePageVibrant extends StatefulWidget {
  const HomePageVibrant({super.key});

  @override
  State<HomePageVibrant> createState() => _HomePageVibrantState();
}

class _HomePageVibrantState extends State<HomePageVibrant> {
  final TextEditingController _searchController = TextEditingController();
  // controller for the sidebar product search (used when pressing "Войти")
  final TextEditingController _sidebarSearchController = TextEditingController();

  static const double _kBaseAppBarH = 140;         // верхняя строка + поле поиска
  static const double _kSuggestionItemH = 48;      // высота одного пункта
  static const double _kSuggestionMaxH = 160;      // максимум для скролла

  // suggestions / autocomplete
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadProductsForSuggestions();
  }
  double get _suggestionsHeight {
    if (!_showSuggestions) return 0;
    final h = _suggestions.length * _kSuggestionItemH;
    return h.clamp(0, _kSuggestionMaxH).toDouble();
  }
  double get _appBarHeight => _kBaseAppBarH + (_showSuggestions ? _suggestionsHeight + 24 : 0);
  Future<void> _loadProductsForSuggestions() async {
    try {
      final raw = await rootBundle.loadString('assets/data/Код, название, ставки.json');
      final list = List<Map<String, dynamic>>.from(jsonDecode(raw) as List);

      // нормализуем к единому виду: id (=код), name (=наименование), tariff (=ставка)
      final rows = list.map((e) {
        final m = Map<String, dynamic>.from(e);
        return {
          'id':      (m['product_code'] ?? '').toString(),
          'name':    (m['product_name'] ?? '').toString(),
          'tariff':  (m['tariff_current'] ?? m['applied_tariff'] ?? '').toString(),
        };
      }).toList();

      setState(() {
        _products = rows;
      });
    } catch (e) {
      debugPrint('Failed to load "Код, название, ставки.json": $e');
      setState(() => _products = []);
    }
  }

  bool _looksLikeTnCode(String q) {
    final onlyDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
    final digitsOnly = RegExp(r'^\d+$').hasMatch(onlyDigits);
    return digitsOnly && onlyDigits.length >= 6;
  }

  void _onSearchFieldChanged(String q) {
    final t = q.trim();
    if (t.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final qLower  = t.toLowerCase();
    final qDigits = t.replaceAll(RegExp(r'\D'), '');

    final byCode = <Map<String, dynamic>>[];
    final byName = <Map<String, dynamic>>[];

    for (final p in _products) {
      final id   = (p['id']   as String? ?? '').replaceAll(' ', '');
      final name = (p['name'] as String? ?? '').toLowerCase();

      if (qDigits.isNotEmpty && id.contains(qDigits)) byCode.add(p);
      if (name.contains(qLower)) byName.add(p);
    }

    // склеиваем, убирая повторы по id
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final p in [...byCode, ...byName]) {
      final id = p['id'] as String? ?? '';
      if (id.isEmpty) continue;
      if (seen.add(id)) merged.add(p);
    }

    setState(() {
      _suggestions = merged.take(6).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  void _onSuggestionTap(Map<String, dynamic> p) {
    final name = p['name'] as String? ?? '';
    // В поле подставляем ТОЛЬКО название
    _searchController.text = name;

    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });

    // Можно искать и по названию — страница сама найдёт по имени
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DataStoryTTRPage(query: name)),
    );
  }

  void _onSearchSubmit() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    final isTn = _looksLikeTnCode(q);
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => DataStoryTTRPage(query: q)));
  }

  // original _onSearch now delegates to submit logic
  void _onSearch() => _onSearchSubmit();

  /// When the header "Войти" button is pressed we show a card-like dialog with
  /// raw data from assets/data/tovars.json for the product present in the sidebar search field.
  Future<void> _onLoginPressed() async {
    final query = _sidebarSearchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите наименование или код ТН ВЭД в поле "Поиск по товарам"')));
      return;
    }

    try {
      final raw = await rootBundle.loadString('assets/data/tovars.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final products = (map['products'] as List<dynamic>?) ?? [];

      Map<String, dynamic>? found;
      final qLower = query.toLowerCase();
      final hsCandidate = RegExp(r'(\d{4,10})').firstMatch(query)?.group(0)?.replaceAll(' ', '');

      for (final p in products) {
        final prod = Map<String, dynamic>.from(p as Map);
        final info = (prod['productInfo'] as Map?)?.cast<String, dynamic>();
        final tn = (info?['tnvedCode'] as String? ?? '').replaceAll(' ', '').toLowerCase();
        final name = (info?['name'] as String? ?? '').toLowerCase();

        if (hsCandidate != null && tn.contains(hsCandidate)) {
          found = prod;
          break;
        }
        if (name.contains(qLower)) {
          found = prod;
          break;
        }
      }

      if (found == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Товар не найден в tovars.json')));
        return;
      }

      // Safe access to nested productInfo
      final productInfo = (found['productInfo'] as Map?)?.cast<String, dynamic>();
      final productName = (productInfo?['name'] as String?) ?? 'Без названия';

      // Flatten top-level keys to rows; lists/maps are pretty-printed JSON in value column
      final rows = <MapEntry<String, String>>[];
      for (final e in found.entries) {
        try {
          rows.add(MapEntry(e.key, const JsonEncoder.withIndent('  ').convert(e.value)));
        } catch (_) {
          rows.add(MapEntry(e.key, e.value.toString()));
        }
      }

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Сырые данные: $productName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [DataColumn(label: Text('Ключ')), DataColumn(label: Text('Значение'))],
                        rows: rows.map((r) {
                          return DataRow(cells: [DataCell(Text(r.key)), DataCell(SelectableText(r.value))]);
                        }).toList(),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при загрузке tovars.json: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sidebarSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Параметры для дропдауна подсказок
    const double baseAppBarH = 140;     // базовая высота шапки без подсказок
    const double itemH = 48;            // высота строки подсказки
    const double maxListH = 180;        // максимум высоты списка (дальше скролл)

    final double suggestionsH = _showSuggestions
        ? (_suggestions.length * itemH).clamp(0.0, maxListH).toDouble()
        : 0.0;

    final double appBarH =
        baseAppBarH + (_showSuggestions ? suggestionsH + 24 : 0);

    return Scaffold(
      // Header с динамической высотой под список подсказок
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarH),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kBlue1, kBlue2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
            ],
          ),
          padding: const EdgeInsets.only(top: 28, left: 18, right: 18, bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: const [
                  Icon(Icons.data_usage, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  _HeaderTitle()
                ]),
                TextButton.icon(
                  onPressed: _onLoginPressed,
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text('Войти', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 12),

              // Подсказки (красивый дропдаун со скроллом, без overflow)
              if (_showSuggestions) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: suggestionsH),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (ctx, i) {
                          final p = _suggestions[i];
                          final id = p['id'] as String? ?? '';
                          final name = p['name'] as String? ?? '';
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text('$id — $name',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _onSuggestionTap(p),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Поле поиска
              Row(children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.search, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Поиск по товарам — наименование или код ТН ВЭД (6/10)',
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _onSearchSubmit(),
                          onChanged: _onSearchFieldChanged,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Кнопка "Найти"
                      ElevatedButton(
                        onPressed: _onSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlue1,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        child: const Text('Найти', style: TextStyle(color: Colors.white)),
                      ),

                      const SizedBox(width: 8),

                      // ⬇️ Квадратная кнопка AI
                      SizedBox(
                        width: 46,
                        height: 26,
                        child: ElevatedButton(
                          onPressed: () => openNpaBotDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlue1,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),

      body: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 28, vertical: 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: isNarrow ? _buildColumn() : _buildTwoColumns(),
          ),
        );
      }),
      bottomNavigationBar: _buildFooter(),
    );
  }


  Widget _buildTwoColumns() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              // CategoriesRow(),                // ← убрать
              // SizedBox(height: 16),           // ← убрать
              HeroCard(),
              SizedBox(height: 18),
              NewsSection(),
              SizedBox(height: 18),
              DatasetsCard(),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Sidebar(controller: _sidebarSearchController),
              SizedBox(height: 16),
              PopularCard(),
              SizedBox(height: 16),
              NormativeCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        // CategoriesRow(),                   // ← убрать
        // SizedBox(height: 12),              // ← убрать
        HeroCard(),
        SizedBox(height: 14),
        NewsSection(),
        SizedBox(height: 14),
        PopularCard(),
        SizedBox(height: 14),
        DatasetsCard(),
        SizedBox(height: 14),
        NormativeCard(),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      color: kBlue1,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('© 2025 ЕАИС', style: TextStyle(color: Colors.white)), Text('Контакты · Политика конфиденциальности', style: TextStyle(color: Colors.white70))]),
    );
  }
}



// ---------------- Widgets ----------------

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({super.key});
  @override
  Widget build(BuildContext context) {
    return const Text(
      'ЕАИС — единая информационно-аналитическая система',
      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}



class HeroCard extends StatefulWidget {
  const HeroCard({super.key});
  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  String? _heroImage;

  @override
  void initState() {
    super.initState();
    _loadHeroImage();
  }

  Future<void> _loadHeroImage() async {
    try {
      final raw = await rootBundle.loadString('assets/data/news.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final list = (map['news'] as List<dynamic>? ?? []);
      final first = list.isNotEmpty ? Map<String, dynamic>.from(list.first as Map) : null;
      setState(() {
        _heroImage = (first?['picture'] as String?) ??
            'https://picsum.photos/seed/hero/600/400';
      });
    } catch (_) {
      setState(() {
        _heroImage = 'https://picsum.photos/seed/hero/600/400';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Портал открытых данных и аналитики',
                    style: TextStyle(color: kBlue1, fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('Поиск, реестры и аналитика по товарам, таможенным мерам и импорту.'),
                SizedBox(height: 12),
                _StatRow(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _heroImage == null
                  ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
                  : Image.network(
                _heroImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 32, color: Colors.black45),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}


class _StatRow extends StatelessWidget {
  const _StatRow({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: const [StatItem(label: 'Наборы', value: '364 095'), SizedBox(width: 12), StatItem(label: 'Организации', value: '2 134'), SizedBox(width: 12), StatItem(label: 'API', value: 'доступно')]);
  }
}

class StatItem extends StatelessWidget {
  final String label;
  final String value;
  const StatItem({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: kBlue1, fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 4), Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12))]);
  }
}

// ---------------- News (из news.json) ----------------

class NewsSection extends StatefulWidget {
  const NewsSection({super.key});
  @override
  State<NewsSection> createState() => _NewsSectionState();
}

class _NewsSectionState extends State<NewsSection> {
  List<Map<String, dynamic>> _news = [];
  String? _error;
  bool _loading = true;

  String? heroImageUrl; // для HeroCard

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      final raw = await rootBundle.loadString('assets/data/news.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final list = List<Map<String, dynamic>>.from(
        (map['news'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      setState(() {
        _news = list;
        heroImageUrl = list.isNotEmpty ? (list.first['picture'] as String?) : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить новости: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Новости', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          TextButton(onPressed: () {}, child: const Text('Все новости')),
        ],
      ),
      const SizedBox(height: 8),
      if (_loading)
        const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
      else if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        )
      else if (_news.isEmpty)
          const Text('Пока нет новостей.')
        else
          SizedBox(
            height: 340,            // было 300
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _news.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (ctx, i) {
                final n = _news[i];
                return SizedBox(
                  width: 420,        // было 380
                  child: NewsCard(
                    title: n['name'] as String? ?? 'Без названия',
                    description: n['description'] as String? ?? '',
                    picture: n['picture'] as String? ?? '',
                    link: n['link'] as String? ?? '',
                  ),
                );
              },
            ),
          )
    ]);
  }
}

class NewsCard extends StatelessWidget {
  final String title;
  final String description;
  final String picture;
  final String link;

  const NewsCard({
    super.key,
    required this.title,
    required this.description,
    required this.picture,
    required this.link,
  });

  Future<void> _openLink(BuildContext context) async {
    if (link.isEmpty) return;
    try {
      await launchUrl(Uri.parse(link));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть ссылку: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Картинка
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Image.network(
              picture.isNotEmpty ? picture : 'https://picsum.photos/seed/news/600/300',
              height: 120, // чуть меньше — больше места тексту
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 32, color: Colors.black45),
              ),
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 120,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              },
            ),
          ),

          // Контент
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок (до 2 строк)
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Описание занимает всё оставшееся пространство, затем троеточие
                  Expanded(
                    child: Text(
                      description,
                      softWrap: true,
                      maxLines: 10, // больше текста на карточке
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Кнопка всегда внизу и кликабельна
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton.icon(
                      onPressed: () => _openLink(context),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Подробнее', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(88, 36),
                        foregroundColor: kBlue1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}


class DatasetsCard extends StatelessWidget {
  const DatasetsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final items = List.generate(6, (i) => {
      'title': [
        'Реестр образовательных учреждений',
        'Статистика здравоохранения по регионам',
        'Бюджетные данные 2025',
        'Данные по транспортной инфраструктуре'
      ][i % 4],
      'org': ['Минобр', 'Минздрав', 'Минфин', 'Минтранс'][i % 4],
      'format': ['CSV, JSON', 'CSV, XML', 'CSV, JSON', 'CSV'][i % 4],
      'date': ['2025-10-15', '2025-10-10', '2025-10-05', '2025-09-28'][i % 4]
    });

    return Card(
      color: kCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Наборы данных', style: TextStyle(color: kBlue1, fontSize: 18, fontWeight: FontWeight.w700)), Row(children: [TextButton(onPressed: () {}, child: const Text('Фильтры')), const SizedBox(width: 8)])]),
          const SizedBox(height: 10),
          Column(children: items.map((it) {
            return ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), title: Text(it['title']! as String), subtitle: Text('${it['org']} · ${it['format']}'), trailing: Text(it['date']! as String));
          }).toList())
        ]),
      ),
    );
  }
}

class Sidebar extends StatelessWidget {
  final TextEditingController controller;
  const Sidebar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Поиск по товарам', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(hintText: 'наименование — код ТН ВЭД', border: OutlineInputBorder()), controller: controller),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () {
                  final q = controller.text.trim();
                  if (q.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите наименование или код ТН ВЭД')));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DataStoryTTRPage(query: q)));
                },
                style: ElevatedButton.styleFrom(backgroundColor: kBlue1),
                child: const Text('Искать', style: TextStyle(color: Colors.white)))
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Популярные категории', style: TextStyle(fontWeight: FontWeight.w700, color: kBlue1)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: ['Импорт', 'Экспорт', 'Контроль и инспекция', 'Тарифы и пошлины', 'Нормативные акты'].map((t) => Chip(label: Text(t))).toList())]),
        ),
      )
    ]);
  }
}

// --- Popular (из cnt.json) ---

class PopularCard extends StatefulWidget {
  const PopularCard({super.key});

  @override
  State<PopularCard> createState() => _PopularCardState();
}

class _PopularCardState extends State<PopularCard> {
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCnt();
  }

  Future<void> _loadCnt() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cnt.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final list = List<Map<String, dynamic>>.from(
        (map['tovars'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      // сортируем по rating (desc), берём топ-4
      list.sort((a, b) {
        num ra = num.tryParse('${a['rating'] ?? 0}') ?? 0;
        num rb = num.tryParse('${b['rating'] ?? 0}') ?? 0;
        return rb.compareTo(ra);
      });

      setState(() {
        _items = list.take(4).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить cnt.json: $e';
        _loading = false;
      });
    }
  }

  void _openItem(Map<String, dynamic> it) {
    final name = (it['name'] as String?) ?? '';
    if (name.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DataStoryTTRPage(query: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Популярные товары и услуги',
                style: TextStyle(color: kBlue1, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_loading)
              const SizedBox(height: 96, child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_items.isEmpty)
                const Text('Нет данных для отображения.')
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3,
                  children: _items.map((it) {
                    return PopularTile(
                      title: (it['name'] as String?) ?? '—',
                      img: (it['picture'] as String?) ??
                          'https://picsum.photos/seed/placeholder/400/300',
                      onTap: () => _openItem(it),
                    );
                  }).toList(),
                ),
          ],
        ),
      ),
    );
  }
}

class PopularTile extends StatelessWidget {
  final String title;
  final String img;
  final VoidCallback? onTap;

  const PopularTile({
    super.key,
    required this.title,
    required this.img,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(foregroundColor: kBlue1),
                child: const Text('Перейти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------- Normative (NPA) block (kept) ----------------

class NormativeCard extends StatelessWidget {
  const NormativeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Нормативно-правовая база (Таможня)', style: TextStyle(color: kBlue1, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          _NormativeDocsWidget(),
        ]),
      ),
    );
  }
}

class _NormativeDocsWidget extends StatefulWidget {
  const _NormativeDocsWidget({super.key});

  @override
  State<_NormativeDocsWidget> createState() => _NormativeDocsWidgetState();
}

class _NormativeDocsWidgetState extends State<_NormativeDocsWidget> {
  List<dynamic>? _docs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    try {
      final raw = await rootBundle.loadString('assets/data/first_10.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final docs = map['documents'] as List<dynamic>?;
      setState(() {
        _docs = docs ?? [];
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить документы: $e';
      });
    }
  }

  Future<void> _downloadDocument(String pdfPath, String filename) async {
    // sanitize backslashes from JSON path and build asset-relative URL
    var p = pdfPath.replaceAll('\\', '/').replaceAll("'", '');
    if (p.startsWith('/')) p = p.substring(1);
    final assetUrl = 'assets/data/$p';

    if (kIsWeb) {
      // Try to open the asset URL (on web it will attempt to display or download)
      final uri = Uri.parse(assetUrl);
      try {
        await launchUrl(uri);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть файл: $filename — $e')));
      }
    } else {
      // On non-web builds, assets cannot be directly downloaded from the bundle. Provide feedback.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скачивание доступно только в веб-версии (assets подгружаются на веб-сервере).')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text(_error!, style: const TextStyle(color: Colors.red));
    if (_docs == null) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));

    return Column(children: _docs!.map((d) {
      final doc = Map<String, dynamic>.from(d as Map);
      final title = doc['title'] as String? ?? 'Без названия';
      final date = doc['registration_date'] as String? ?? '';
      final pdfPath = doc['pdf_path'] as String? ?? '';
      final filename = doc['pdf_filename'] as String? ?? 'file.pdf';
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        leading: const Icon(Icons.description, color: kBlue1),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(date),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton.icon(
            onPressed: () => _downloadDocument(pdfPath, filename),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Скачать'),
            style: TextButton.styleFrom(foregroundColor: kBlue1, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ]),
      );
    }).toList());
  }
}

// ---------------- Analysis Result (product_data-driven) ----------------

class AnalysisResultPage extends StatefulWidget {
  final String query;
  final bool showOnlyTables; // NEW

  const AnalysisResultPage({super.key, required this.query, this.showOnlyTables = false});

  @override
  State<AnalysisResultPage> createState() => _AnalysisResultPageState();
}


class _AnalysisResultPageState extends State<AnalysisResultPage> {
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _tovarsEntry; // <- entry from tovars.json (raw)
  String? _error;
  String? _tovarsError;
  bool _loading = true;
  bool _loadingTovars = true;

  // selected year for per-year stats
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final raw = await rootBundle.loadString('assets/data/product_data.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final products = (map['products'] as List<dynamic>?) ?? [];

      final query = widget.query.trim().toLowerCase();
      final hsCandidate = RegExp(r'(\d{4,10})').firstMatch(widget.query)?.group(0)?.replaceAll(' ', '');

      Map<String, dynamic>? found;
      for (final p in products) {
        final prod = Map<String, dynamic>.from(p as Map);
        final name = (prod['name'] as String? ?? '').toLowerCase();
        final tn = (prod['tnvedCode'] as String? ?? '').replaceAll(' ', '').toLowerCase();

        if (hsCandidate != null && tn.contains(hsCandidate)) {
          found = prod;
          break;
        }
        if (query.isNotEmpty && name.contains(query)) {
          found = prod;
          break;
        }
      }

      setState(() {
        _product = found ?? (products.isNotEmpty ? Map<String, dynamic>.from(products.first as Map) : null);
        _loading = false;
      });

      // set default selected year (latest from dynamics) after load
      if (_product != null) {
        final dyn = List<Map<String, dynamic>>.from(_product!['dynamics'] as List<dynamic>);
        if (dyn.isNotEmpty) {
          setState(() => _selectedYear = dyn.last['year'] as String);
        }
      }

      // Now try to load tovars.json entry matching tnved code or name
      await _loadTovarsEntry(widget.query);
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить данные: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadTovarsEntry(String query) async {
    setState(() {
      _loadingTovars = true;
      _tovarsEntry = null;
      _tovarsError = null;
    });

    try {
      final raw = await rootBundle.loadString('assets/data/tovars.json');
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final products = (map['products'] as List<dynamic>?) ?? [];

      final qNorm = query.toLowerCase().replaceAll(' ', '');
      final hsCandidate = RegExp(r'(\d{4,10})').firstMatch(query)?.group(0)?.replaceAll(' ', '');

      Map<String, dynamic>? found;
      for (final p in products) {
        final prod = Map<String, dynamic>.from(p as Map);
        final info = (prod['productInfo'] as Map?)?.cast<String, dynamic>();
        final tn = (info?['tnvedCode'] as String? ?? '').replaceAll(' ', '').toLowerCase();
        final name = (info?['name'] as String? ?? '').toLowerCase();

        if (hsCandidate != null && tn.contains(hsCandidate)) {
          found = prod;
          break;
        }
        if (qNorm.isNotEmpty && name.replaceAll(' ', '').contains(qNorm)) {
          found = prod;
          break;
        }
      }

      setState(() {
        _tovarsEntry = found;
        _loadingTovars = false;
      });
    } catch (e) {
      setState(() {
        _tovarsError = 'Не удалось загрузить tovars.json: $e';
        _loadingTovars = false;
      });
    }
  }

  // Helper: mini card wrapper
  Widget _miniDataCard(String title, Widget child) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: kBlue1, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ])),
    );
  }

  // Helper: key-value table for a Map
  Widget _mapAsTable(Map<String, dynamic> m) {
    final rows = m.entries.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 12,
          columns: const [DataColumn(label: Text('Ключ')), DataColumn(label: Text('Значение'))],
          rows: rows.map((e) {
            final v = e.value;
            final valStr = (v is Map || v is List) ? const JsonEncoder.withIndent('  ').convert(v) : v.toString();
            return DataRow(cells: [DataCell(Text(e.key)), DataCell(SelectableText(valStr))]);
          }).toList(),
        ),
      ),
    );
  }

  // Helper: list of maps as table (e.g., dynamics)
  Widget _listOfMapsAsTable(List<dynamic> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    final first = Map<String, dynamic>.from(list.first as Map);
    final cols = first.keys.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: cols.map((c) => DataColumn(label: Text(c))).toList(),
          rows: list.map((r) {
            final map = Map<String, dynamic>.from(r as Map);
            return DataRow(
              cells: cols.map((c) => DataCell(Text('${map[c] ?? ''}'))).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Helper: simple two-column table for list of {name, value}
  Widget _nameValueListAsTable(List<dynamic> list) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [DataColumn(label: Text('Наименование')), DataColumn(label: Text('Значение'))],
          rows: list.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            return DataRow(cells: [DataCell(Text(m['name']?.toString() ?? '')), DataCell(Text(m['value']?.toString() ?? ''))]);
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // existing loading/error/no-data handling (unchanged)
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Результат анализа'), backgroundColor: kBlue1), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Результат анализа'), backgroundColor: kBlue1), body: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))));
    }
    if (_product == null) {
      return Scaffold(appBar: AppBar(title: const Text('Результат анализа'), backgroundColor: kBlue1), body: const Padding(padding: EdgeInsets.all(16), child: Text('Нет данных для отображения.')));
    }

    final name = _product!['name'] as String? ?? '';
    final tn = _product!['tnvedCode'] as String? ?? '';
    final dynamics = List<Map<String, dynamic>>.from(_product!['dynamics'] as List<dynamic>);
    final geo = List<Map<String, dynamic>>.from(_product!['geo'] as List<dynamic>);
    final avgPrices = List<Map<String, dynamic>>.from(_product!['avgPrices'] as List<dynamic>);

    // Responsive chart height calculation (prevents overflow)
    final screenH = MediaQuery.of(context).size.height;
    final topBarH = kToolbarHeight + MediaQuery.of(context).padding.top;
    final available = (screenH - topBarH - 220).clamp(240.0, 1200.0);
    final chartHeight = (available * 0.45).clamp(220.0, 380.0);

    final years = dynamics.map((d) => d['year'] as String).toList();

    // get values for the selected year
    Map<String, dynamic>? yearRow;
    if (_selectedYear != null) {
      try {
        yearRow = dynamics.firstWhere((d) => d['year'] == _selectedYear);
      } catch (_) {
        yearRow = null;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(name.isNotEmpty ? 'Результат: $name' : 'Результат анализа'), backgroundColor: kBlue1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // header
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Код ТН ВЭД: $tn', style: TextStyle(color: Colors.grey[800])),
          const SizedBox(height: 12),

          // If tovars entry found — show mini-cards (raw data) at the top (compact)
          if (_loadingTovars)
            const SizedBox.shrink()
          else if (_tovarsError != null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_tovarsError!, style: const TextStyle(color: Colors.red)))
          else if (_tovarsEntry != null) ...[
              // Render a horizontal row of small cards (wrap if narrow)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // productInfo
                  SizedBox(width: 360, child: _miniDataCard('TOVARS: productInfo', _mapAsTable((( _tovarsEntry!['productInfo'] as Map?)?.cast<String, dynamic>() ?? <String,dynamic>{})))),
                  // marketConcentration (if exists)
                  if ((_tovarsEntry!['marketConcentration']) != null)
                    SizedBox(width: 260, child: _miniDataCard('Маркет. концентрация', _mapAsTable((( _tovarsEntry!['marketConcentration'] as Map?)?.cast<String, dynamic>() ?? <String,dynamic>{})))),
                  // priceStats (if exists)
                  if ((_tovarsEntry!['priceStats']) != null)
                    SizedBox(width: 260, child: _miniDataCard('Price stats', _mapAsTable((( _tovarsEntry!['priceStats'] as Map?)?.cast<String, dynamic>() ?? <String,dynamic>{})))),
                  // quick lists
                  SizedBox(width: 340, child: _miniDataCard('Geo (top)', _nameValueListAsTable(List<dynamic>.from(_tovarsEntry!['geo'] as List<dynamic>)))),
                  SizedBox(width: 340, child: _miniDataCard('Avg Prices (top)', _nameValueListAsTable(List<dynamic>.from(_tovarsEntry!['avgPrices'] as List<dynamic>)))),
                ],
              ),
              const SizedBox(height: 12),
            ],

          // dynamics full chart (unchanged)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Динамика: импорт / производство / потребление', style: TextStyle(color: kBlue1, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(height: 320, child: SfCartesianChart(legend: Legend(isVisible: true, position: LegendPosition.bottom), tooltipBehavior: TooltipBehavior(enable: true), primaryXAxis: CategoryAxis(), primaryYAxis: NumericAxis(labelFormat: '{value}'), series: <CartesianSeries<Map<String, dynamic>, String>>[
                LineSeries<Map<String, dynamic>, String>(name: 'Импорт', dataSource: dynamics, xValueMapper: (d, _) => d['year'] as String, yValueMapper: (d, _) => (d['Импорт'] as num), color: kBlue1, width: 3, markerSettings: const MarkerSettings(isVisible: true)),
                LineSeries<Map<String, dynamic>, String>(name: 'Производство', dataSource: dynamics, xValueMapper: (d, _) => d['year'] as String, yValueMapper: (d, _) => (d['Производство'] as num), color: Colors.green, width: 3, markerSettings: const MarkerSettings(isVisible: true)),
                LineSeries<Map<String, dynamic>, String>(name: 'Потребление', dataSource: dynamics, xValueMapper: (d, _) => d['year'] as String, yValueMapper: (d, _) => (d['Потребление'] as num), color: Colors.red, width: 3, markerSettings: const MarkerSettings(isVisible: true)),
              ])),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Text('Выберите год: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(value: _selectedYear, items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(), onChanged: (v) => setState(() => _selectedYear = v)),
                ]),
                if (yearRow != null) Row(children: [Chip(label: Text('Импорт: ${yearRow['Импорт']}')), const SizedBox(width: 8), Chip(label: Text('Произв: ${yearRow['Производство']}')), const SizedBox(width: 8), Chip(label: Text('Потр: ${yearRow['Потребление']}'))])
              ])
            ])),
          ),

          const SizedBox(height: 12),

          // География импорта — donut + legend scroll
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('География импорта', style: TextStyle(color: kBlue1, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(height: chartHeight, child: Row(children: [
                Expanded(flex: 2, child: SfCircularChart(tooltipBehavior: TooltipBehavior(enable: true), legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[DoughnutSeries<Map<String, dynamic>, String>(dataSource: geo, xValueMapper: (d, _) => d['name'] as String, yValueMapper: (d, _) => d['value'] as num, dataLabelMapper: (d, _) => '${d['value']}% ', dataLabelSettings: const DataLabelSettings(isVisible: true), innerRadius: '60%'),])),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: chartHeight, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: geo.map((g) {
                  final colorIndex = geo.indexOf(g) % 5;
                  final color = [kBlue1, kAccent, Colors.green.shade700, Colors.purple, Colors.orange][colorIndex];
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text(g['name'] as String)]), Text('${g['value']}%', style: const TextStyle(color: Colors.black54))]));
                }).toList()))))
              ]))
            ])),
          ),

          const SizedBox(height: 12),

          // Avg prices donut + details
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Средние контрактные цены (USD/т)', style: TextStyle(color: kBlue1, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(height: chartHeight, child: Row(children: [
                Expanded(flex: 2, child: SfCircularChart(tooltipBehavior: TooltipBehavior(enable: true), legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap), series: <CircularSeries>[DoughnutSeries<Map<String, dynamic>, String>(dataSource: avgPrices, xValueMapper: (d, _) => d['name'] as String, yValueMapper: (d, _) => d['value'] as num, dataLabelMapper: (d, _) => '${d['value']}', dataLabelSettings: const DataLabelSettings(isVisible: true), innerRadius: '60%'),])),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: chartHeight, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: avgPrices.map((g) {
                  final idx = avgPrices.indexOf(g) % 5;
                  final color = [kBlue1, kAccent, Colors.green.shade700, Colors.purple, Colors.orange][idx];
                  return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Text(g['name'] as String)]), Text('${g['value']} USD/т', style: const TextStyle(color: Colors.black54))]));
                }).toList()))))
              ]))
            ])),
          ),

          const SizedBox(height: 12),
          const Text('Примечание: данные загружены из assets/data/product_data.json (демонстрация).'),
        ]),
      ),
    );
  }
}

