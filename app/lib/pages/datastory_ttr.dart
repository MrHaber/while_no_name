import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:syncfusion_flutter_maps/maps.dart';
import '../widgets/world_choropleth.dart';
// (оставляю — вдруг используешь графики где-то ещё)
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';

// ---------- палитра ----------
const kBlue = Color(0xFF0D5FE5);
const kSky50 = Color(0xFFEFF6FF);
const kCard = Colors.white;

// ---------- утилиты ----------
String s(Object? v) => v?.toString() ?? '';
num n(Object? v) => v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
bool b(Object? v) => v is bool ? v : (v?.toString().toLowerCase() == 'true');
String fmtUSD(num x) =>
    NumberFormat.currency(locale: 'ru_RU', symbol: '\$', decimalDigits: 0).format(x);
String fmtPct(num x, {int d = 2}) => '${x.toStringAsFixed(d)}%';
String fmtT(num x) => '${x.toStringAsFixed(0)} т';

// безопасный доступ к вложенным ключам (для «Описание блоков.json»)
T _getIn<T>(Map m, List path, T fallback) {
  dynamic cur = m;
  for (final p in path) {
    if (cur is Map && cur.containsKey(p)) {
      cur = cur[p];
    } else {
      return fallback;
    }
  }
  return (cur is T) ? cur : fallback;
}

// ---------- бейдж ----------
class Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final bool active;
  final VoidCallback? onTap;
  const Badge(
      this.text, {
        super.key,
        this.bg = const Color(0xFFEFF6FF),
        this.fg = const Color(0xFF1E40AF),
        this.active = false,
        this.onTap,
      });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? kBlue : bg.withOpacity(.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12, color: active ? kBlue : fg, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

// ---------- мини-карта статуса ----------
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  const StatCard({super.key, required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
      border: Border.all(color: Colors.black12.withOpacity(.06)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(hint!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ),
    ]),
  );
}

// ---------- горизонтальный рейтинг ----------
class HBarList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String valueKey;
  final String labelKey;
  const HBarList(
      {super.key, required this.items, required this.valueKey, required this.labelKey});

  @override
  Widget build(BuildContext context) {
    final maxVal = items.fold<num>(0, (m, e) {
      final v = n(e[valueKey]);
      return v > m ? v : m;
    });
    return Column(
        children: items.map((it) {
          final v = n(it[valueKey]);
          final w = maxVal == 0 ? 0.0 : (v / maxVal) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                    child: Text(s(it[labelKey]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text(fmtT(v), style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                      minHeight: 8, value: w / 100, color: kBlue, backgroundColor: Colors.black12.withOpacity(.08))),
            ]),
          );
        }).toList());
  }
}

// --- «синий» заголовок внутри KPI-карточек ---
class KpiBlueCard extends StatelessWidget {
  final String title; // напр.: "Импорт 2024"
  final String value; // напр.: "$306 844 000"
  final String? yoy; // напр.: "YoY: +2.28%"
  const KpiBlueCard({super.key, required this.title, required this.value, this.yoy});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECFF)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FF),
            border: Border.all(color: const Color(0xFFDBE7FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(title,
              style: const TextStyle(
                  color: Color(0xFF0D5FE5), fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        if (yoy != null && yoy!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(yoy!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ]),
    );
  }
}

// ---------- голубой информационный бейдж ----------
class InfoNote extends StatelessWidget {
  final String title;
  final String text;
  const InfoNote({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSky50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FF),
            border: Border.all(color: const Color(0xFFDBE7FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(title,
              style: const TextStyle(
                  color: kBlue, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black87))),
      ]),
    );
  }
}

// ===================================================================
//                           СТРАНИЦА
// ===================================================================
class DataStoryTTRPage extends StatefulWidget {
  final String query; // может быть код ТН ВЭД или название
  const DataStoryTTRPage({super.key, required this.query});
  @override
  State<DataStoryTTRPage> createState() => _DataStoryTTRPageState();
}
// --- мини-колоночные графики -------------------------------------------------

class _BarPoint {
  final String x;
  final double y;
  _BarPoint(this.x, this.y);
}

List<_BarPoint> _seriesToPoints(List<Map<String, dynamic>> s) {
  final sorted = [...s]..sort((a, b) => (a['year'] as int).compareTo(b['year'] as int));
  return sorted
      .map((e) => _BarPoint('${e['year']}', n(e['usd']).toDouble()))
      .toList();
}

class _DataStoryTTRPageState extends State<DataStoryTTRPage> {
  late Future<void> _init;
  String? _pickedCountry;
  final _pdfKey = GlobalKey();          // что будем «фотографировать»
  bool _exporting = false;              // чтобы дизейблить кнопку во время экспорта

  // --- навигация / скролл ---
  final _scroll = ScrollController();
  final ScreenshotController _shot = ScreenshotController();
  final _kPassport = GlobalKey();
  final _kBalance = GlobalKey();
  final _kGeo = GlobalKey();
  final _kPrice = GlobalKey();
  final _kDecision = GlobalKey();

  void _goTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  // подписи из «Описание блоков.json»
  Map<String, dynamic> _labels = {};

  // Паспорт
  String name = '';
  String code = '';
  num tariff = 0; // применяемая
  num wto = 0; // связанная (ВТО)

  // Ряды (USD)
  final List<Map<String, dynamic>> importSeries = [];
  final List<Map<String, dynamic>> productionSeries = [];
  final List<Map<String, dynamic>> consumptionSeries = [];

  // Гео и цены
  final List<Map<String, dynamic>> geoTop24 = [];
  final List<Map<String, dynamic>> geoTop23 = [];
  final List<Map<String, dynamic>> priceTop5 = [];
  final List<Map<String, dynamic>> volumeTop = []; // Топ-10 по тоннажу (2024)

  // НС
  num nsShare24 = 0;
  num nsYoY = 0;

  Map<String, dynamic>? recommendation;
  int year = 0;



  @override
  void initState() {
    super.initState();
    _init = _loadAll(widget.query);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }


  Widget _miniBarCard(String title, Color color, List<Map<String, dynamic>> series) {
    final data = _seriesToPoints(series);
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECFF)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "синий" чип-заголовок, как у KPI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FF),
              border: Border.all(color: const Color(0xFFDBE7FF)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(title,
                style: const TextStyle(
                    color: kBlue, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
                labelStyle: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              primaryYAxis: NumericAxis(
                isVisible: false,
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
              ),
              series: <ColumnSeries<_BarPoint, String>>[
                ColumnSeries<_BarPoint, String>(
                  dataSource: data,
                  xValueMapper: (p, _) => p.x,
                  yValueMapper: (p, _) => p.y,
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  isTrackVisible: true,
                  trackColor: const Color(0xFFF1F5FF),
                  dataLabelSettings: const DataLabelSettings(isVisible: false),
                )
              ],
              tooltipBehavior:
              TooltipBehavior(enable: true, format: 'point.x: \$point.y'),
            ),
          ),
        ],
      ),
    );
  }
  // -----------------------------------------------------------------
  //                         Загрузка данных
  // -----------------------------------------------------------------
  Future<void> _loadAll(String query) async {
    // 1) Подписи / описания
    try {
      final raw = await rootBundle.loadString('assets/data/Описание блоков.json');
      _labels = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _labels = {};
    }

    // 2) Паспорт
    final passRows =
    jsonDecode(await rootBundle.loadString('assets/data/Код, название, ставки.json'))
    as List;
    final q = query.toLowerCase().trim();
    final digits = RegExp(r'\d+').allMatches(q).map((m) => m.group(0)!).join();

    Map<String, dynamic>? pass;
    for (final r in passRows) {
      final m = Map<String, dynamic>.from(r as Map);
      final codeStr = s(m['product_code']);
      final nm = s(m['product_name']).toLowerCase();
      if (digits.isNotEmpty && codeStr.contains(digits)) {
        pass = m;
        break;
      }
      if (q.isNotEmpty && nm.contains(q)) {
        pass = m;
        break;
      }
    }
    if (pass == null) throw 'Товар не найден по запросу: $query';

    name = s(pass['product_name']);
    code = s(pass['product_code']);
    tariff = n(pass['tariff_current'] ?? pass['applied_tariff']);
    wto = n(pass['tariff_bound_wto'] ?? pass['wto_bound_tariff'] ?? 5);

    // 3) Импорт
    final impList =
    jsonDecode(await rootBundle.loadString('assets/data/Объем и динамика импорта.json'))
    as List;
    for (final e in impList) {
      final m = Map<String, dynamic>.from(e as Map);
      if (s(m['product_code']) == code) {
        for (final y in (m['last_three_years'] as List)) {
          final yy = n((y as Map)['year']).toInt();
          importSeries.add({
            'year': yy,
            'usd': n(y['import_value_usd']),
            't': n(y['import_weight_t'] ?? y['import_value_tones']),
          });
        }
      }
    }

    // 4) Производство
    final prodList = jsonDecode(
        await rootBundle.loadString('assets/data/Объем и динамика производства.json'))
    as List;
    for (final e in prodList) {
      final m = Map<String, dynamic>.from(e as Map);
      if (s(m['product_code']) == code) {
        for (final y in (m['last_three_years'] as List)) {
          productionSeries.add({
            'year': n((y as Map)['year']).toInt(),
            'usd': n(y['production_value_usd']),
          });
        }
      }
    }

    // 5) Потребление
    final consList = jsonDecode(
        await rootBundle.loadString('assets/data/Объем и динамика потребления.json'))
    as List;
    for (final e in consList) {
      final m = Map<String, dynamic>.from(e as Map);
      if (s(m['product_code']) == code) {
        for (final y in (m['last_three_years'] as List)) {
          final ym = Map<String, dynamic>.from(y as Map);
          consumptionSeries.add({
            'year': n(ym['year']).toInt(),
            'usd': n(ym['consumtion_value_usd'] ?? ym['consumption_value_usd']),
          });
        }
      }
    }

    // 6) География импорта
    final geoList = jsonDecode(
        await rootBundle.loadString('assets/data/Географическая структура импорта.json'))
    as List;
    final geoRow =
    geoList.map((e) => Map<String, dynamic>.from(e as Map)).firstWhere(
          (e) => s(e['product_code']) == code,
      orElse: () => {},
    );

    for (final y in (geoRow['geo_structure_by_year'] as List? ?? const [])) {
      final ym = Map<String, dynamic>.from(y as Map);
      final yr = n(ym['year']).toInt();
      final list = (ym['top_countries'] as List? ?? const []);
      if (yr == 2024) {
        for (final c in list) {
          final cm = Map<String, dynamic>.from(c as Map);
          geoTop24.add({
            'name': s(cm['country'] ?? cm['name']),
            'usd': n(cm['import_value_usd']),
            'share': n(cm['share_percent'] ?? cm['share']),
            'friendly': b(cm['is_friendly'] ?? cm['friendly']),
          });
        }
      } else if (yr == 2023) {
        for (final c in list) {
          final cm = Map<String, dynamic>.from(c as Map);
          geoTop23.add({
            'name': s(cm['country'] ?? cm['name']),
            'usd': n(cm['import_value_usd']),
            'share': n(cm['share_percent'] ?? cm['share']),
            'friendly': b(cm['is_friendly'] ?? cm['friendly']),
          });
        }
      }
    }
    final ns = Map<String, dynamic>.from(geoRow['non_friendly_summary'] as Map? ?? {});
    nsShare24 = n(ns['share_2024_pct']);
    nsYoY = n(ns['yoy_2024_vs_2023_pct']);

    // 7) Средняя контрактная цена (топ-5, 2024) + топ-10 по тоннажу
    final priceList = jsonDecode(
        await rootBundle.loadString('assets/data/Средняя контрактная цена импорта.json'))
    as List;
    final pr =
    priceList.map((e) => Map<String, dynamic>.from(e as Map)).firstWhere(
          (e) => s(e['product_code']) == code,
      orElse: () => {},
    );

    List byYear =
    (pr['avg_contract_price_by_year'] ?? pr['price_by_year'] ?? const []) as List;

    Map y2024 = const {};
    for (final row in byYear) {
      final m = Map<String, dynamic>.from(row as Map);
      if (n(m['year']).toInt() == 2024) {
        y2024 = m;
        break;
      }
    }

    final topAny =
    (y2024['top5_by_value'] ?? y2024['top_countries'] ?? const []) as List;

    final all2024 = topAny.map<Map<String, dynamic>>((c) {
      final cm = Map<String, dynamic>.from(c as Map);
      return {
        'name': s(cm['country'] ?? cm['name']),
        'price': n(cm['avg_contract_price_usd_per_tone'] ??
            cm['avg_price_usd_per_t']),
        't': n(cm['import_weight_t'] ?? cm['import_value_tones']),
        'usd': n(cm['import_value_usd']),
      };
    }).toList();

    final _byPrice = [...all2024]
      ..sort((a, b) => n(b['price']).compareTo(n(a['price'])));
    priceTop5
      ..clear()
      ..addAll(_byPrice.take(5));

    final _byTonnes = [...all2024]
      ..sort((a, b) => n(b['t']).compareTo(n(a['t'])));
    volumeTop
      ..clear()
      ..addAll(_byTonnes.take(10));

    // 8) Рекомендации
    try {
      final recList =
      jsonDecode(await rootBundle.loadString('assets/data/Рекомендуемые меры.json'))
      as List;
      recommendation = recList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .firstWhere((e) => s(e['product_code']) == code, orElse: () => {});
    } catch (_) {}

    // дефолтный год
    final ys = importSeries.map((e) => e['year'] as int).toList()..sort();
    year = ys.isNotEmpty ? ys.last : 0;

    setState(() {});
  }

  // -----------------------------------------------------------------
  //                       Вспомогательные UI
  // -----------------------------------------------------------------
  Widget _block({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12.withOpacity(.08)),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700))),
            if (trailing != null) trailing,
          ]),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ),
          const SizedBox(height: 10),
          child,
        ]),
      );

  num _val(int y, List<Map<String, dynamic>> s) =>
      n(s.firstWhere((e) => e['year'] == y, orElse: () => const {'usd': 0})['usd']);

  String _yoyHint(int y, List<Map<String, dynamic>> s) {
    final idx = s.indexWhere((e) => e['year'] == y);
    if (idx <= 0) return '';
    final cur = n(s[idx]['usd']);
    final prev = n(s[idx - 1]['usd']);
    final v = ((cur - prev) / (prev == 0 ? 1 : prev)) * 100;
    final sign = v > 0 ? '+' : '';
    return 'YoY: $sign${v.toStringAsFixed(2)}%';
  }

  // Соединяем гео-списки 2023 и 2024 по имени
  List<Map<String, dynamic>> _geoRows({
    required List<dynamic>? top2023,
    required List<dynamic>? top2024,
  }) {
    final a23 = (top2023 ?? const [])
        .map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from((e as Map?) ?? const {});
      return {
        'name': s(m['name']).trim(),
        'usd2023': n(m['usd']),
        'share2023': n(m['share']),
        'friendly2023': b(m['friendly']),
      };
    })
        .where((r) => (r['name'] as String).isNotEmpty)
        .toList();

    final a24 = (top2024 ?? const [])
        .map<Map<String, dynamic>>((e) {
      final m = Map<String, dynamic>.from((e as Map?) ?? const {});
      return {
        'name': s(m['name']).trim(),
        'usd2024': n(m['usd']),
        'share2024': n(m['share']),
        'friendly2024': b(m['friendly']),
      };
    })
        .where((r) => (r['name'] as String).isNotEmpty)
        .toList();

    final byName = <String, Map<String, dynamic>>{};
    for (final r in a23) {
      byName[r['name'] as String] = r;
    }
    for (final r in a24) {
      final key = r['name'] as String;
      final base = byName[key] ?? <String, dynamic>{'name': key};
      base['usd2024'] = r['usd2024'];
      base['share2024'] = r['share2024'];
      base['friendly2024'] = r['friendly2024'];
      byName[key] = base;
    }

    return byName.values.map((m) {
      final s23 = n(m['share2023']);
      final s24 = n(m['share2024']);
      final u23 = n(m['usd2023']);
      final u24 = n(m['usd2024']);
      final yoyUsd = u23 == 0 ? null : ((u24 - u23) / u23) * 100;
      return {
        'name': s(m['name']),
        'share2023': s23,
        'share2024': s24,
        'dShare': s24 - s23,
        'usd2023': u23,
        'usd2024': u24,
        'yoyUsd': yoyUsd,
        'friendly': (m['friendly2024'] ?? m['friendly2023']) ?? true,
      };
    }).toList();
  }

  Widget _priceRow(Map<String, dynamic> d) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12.withOpacity(.08)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(
          child: Text(s(d['name']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600))),
      Text('${n(d['price']).round()} \$ /т'),
    ]),
  );

  num _minPrice() => priceTop5.isEmpty
      ? 0
      : priceTop5.fold<num>(1e18, (m, e) {
    final v = n(e['price']);
    return v < m ? v : m;
  });

  num _maxPrice() => priceTop5.isEmpty
      ? 0
      : priceTop5.fold<num>(0, (m, e) {
    final v = n(e['price']);
    return v > m ? v : m;
  });

  Map<String, dynamic> _minHolder() => priceTop5.isEmpty
      ? {'name': '—', 'price': 0}
      : priceTop5.reduce((a, b) => n(a['price']) < n(b['price']) ? a : b);
  Map<String, dynamic> _maxHolder() => priceTop5.isEmpty
      ? {'name': '—', 'price': 0}
      : priceTop5.reduce((a, b) => n(a['price']) > n(b['price']) ? a : b);
  Widget _geoTile(Map<String, dynamic> r) {
    final name     = s(r['name']);
    final share23  = n(r['share2023']);
    final share24  = n(r['share2024']);
    final dpp      = share24 - share23;
    final usd23    = n(r['usd2023']);
    final usd24    = n(r['usd2024']);
    final yoy      = r['yoyUsd'] as num?;
    final friendly = (r['friendly'] as bool?) ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: friendly ? Colors.green : Colors.pinkAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            Text('${share24.toStringAsFixed(3)} %',
                style: const TextStyle(color: Colors.black54)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Доля: ${share23.toStringAsFixed(3)} → ${share24.toStringAsFixed(3)} '
                '(${dpp >= 0 ? '+' : ''}${dpp.toStringAsFixed(3)} п.п.) · '
                'Импорт: ${usd23.toStringAsFixed(0)} → ${usd24.toStringAsFixed(0)} '
                '${yoy == null ? '(н/д)' : '(${yoy >= 0 ? '+' : ''}${yoy.toStringAsFixed(2)}%)'}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }


  // «Пилон» из трёх цветов
  Widget _stackedPillar(int y) {
    final imp = _val(y, importSeries).toDouble();
    final prod = _val(y, productionSeries).toDouble();
    final cons = _val(y, consumptionSeries).toDouble();

    final total = (imp + prod + cons).clamp(1.0, double.infinity);
    int flexFor(double v) =>
        (v <= 0) ? 1 : (v / total * 1000).round().clamp(80, 1000);

    Widget seg(String label, Color color, int flex) => Expanded(
      flex: flex,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color),
        child: Text(label,
            style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECFF)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 300,
          child: Column(children: [
            seg('Импорт', const Color(0xFF0D5FE5), flexFor(imp)),
            seg('Произв.', const Color(0xFF10B981), flexFor(prod)),
            seg('Потребл.', const Color(0xFF64748B), flexFor(cons)),
          ]),
        ),
      ),
    );
  }

  // удобные подписи из «Описание блоков.json» с дефолтами
  String _L(List path, String fallback) => _getIn<String>(_labels, path, fallback);

  // ---- элементы навигации ----
  Widget _topLink(String title, GlobalKey key) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: TextButton(
      onPressed: () => _goTo(key),
      child: Text(title, style: const TextStyle(color: Colors.black87)),
    ),
  );

  Widget _navItem(int n, String label, GlobalKey key) => InkWell(
    onTap: () => _goTo(key),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: kBlue,
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      ]),
    ),
  );

  Future<void> _exportToPdf() async {
    try {
      setState(() => _exporting = true);
      await Future.delayed(const Duration(milliseconds: 50));

      final renderObject = _pdfKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось найти область для экспорта')),
        );
        return;
      }

      final ui.Image image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final doc = pw.Document();
      final img = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
        ),
      );
      await Printing.layoutPdf(
        name: 'ttr_${code}_$year.pdf',
        onLayout: (format) async => doc.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Экспорт не удался: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }


  Widget _leftNav() => Container(
    width: 260,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12.withOpacity(.08)),
      boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exporting ? null : _exportToPdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(_exporting ? 'Экспорт...' : 'Экспорт в PDF'),
          ),
        ),
        const SizedBox(height: 14),
        const Text('НАВИГАЦИЯ',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: .5)),
        const SizedBox(height: 8),
        _navItem(1, 'Паспорт товара', _kPassport),
        _navItem(2, 'Баланс рынка', _kBalance),
        _navItem(3, 'География импорта', _kGeo),
        _navItem(4, 'Средняя контрактная цена', _kPrice),
        _navItem(5, 'Итоговая рекомендация', _kDecision),
      ],
    ),
  );
// В datastory_ttr.dart, рядом с _content() добавь:

  String toGeoName(String ru) {
    const map = {
      'Россия': 'Russia',
      'РФ': 'Russia',
      'Беларусь': 'Belarus',
      'Китай': 'China',
      'Германия': 'Germany',
      'Турция': 'Turkey',
      'Финляндия': 'Finland',
      'Греция': 'Greece',
      'Швейцария': 'Switzerland',
      'Испания': 'Spain',
      'Словакия': 'Slovakia',
      'Швеция': 'Sweden',
      'Эстония': 'Estonia',
      'Республика Корея': 'South Korea',
      'Южная Корея': 'South Korea',
      'Италия': 'Italy',
      'Украина': 'Ukraine',
      'Польша': 'Poland',
      'Сербия': 'Serbia',
      'Литва': 'Lithuania',
      'Дания': 'Denmark',
      'Болгария': 'Bulgaria',
      'Франция': 'France',
      'Бельгия': 'Belgium',
      'Чехия': 'Czechia', // в большинстве geojson сейчас "Czechia"
      'Нидерланды': 'Netherlands',
      'США': 'United States of America',
      'Великобритания': 'United Kingdom',
      'Норвегия': 'Norway',
      'Канада': 'Canada',
      'Южно-Африканская Республика': 'South Africa',
      'Таиланд': 'Thailand',
      'Республика Корея (Южная)': 'South Korea',
      'Казахстан': 'Kazakhstan',
      'Армения': 'Armenia',
      'ОАЭ': 'United Arab Emirates',
      'Объединённые Арабские Эмираты': 'United Arab Emirates',
      'Япония': 'Japan',
      'Люксембург': 'Luxembourg',
      'Латвия': 'Latvia',
      'Словения': 'Slovenia',
      'Тайвань': 'Taiwan',
      'Вьетнам': 'Vietnam',
      // при необходимости дополняй список
    };
    return map[ru.trim()] ?? ru.trim(); // если не нашли — используем как есть
  }
  Widget _tracePanel() {
    // метрики
    final prod = _val(year, productionSeries);
    final cons = _val(year, consumptionSeries);
    final prodOk = prod >= cons;

    // топ-5 стран 2024 по доле
    final top5 = ([...geoTop24]..sort((a, b) => n(b['share']).compareTo(n(a['share']))))
        .take(5)
        .toList();

    Color okBg(bool ok)    => ok ? Colors.green.shade50 : Colors.red.shade50;
    Color okFg(bool ok)    => ok ? Colors.green.shade800 : Colors.red.shade800;
    bool  yoyOk            = nsYoY <= 0; // снижение импорта НС — «зелёный»

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12.withOpacity(.08)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ПАНЕЛЬ ПРОСЛЕЖИВАЕМОСТИ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: .5,
              )),
          const SizedBox(height: 10),

          // базовые метки
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Badge('Код: $code',
                  bg: const Color(0xFFEAF1FF), fg: const Color(0xFF1E40AF)),
              Badge('Тариф: ${tariff.toStringAsFixed(0)}% → ВТО ${wto.toStringAsFixed(0)}%',
                  bg: const Color(0xFFFFF3E0), fg: const Color(0xFF9A3412)),
              Badge('Доля HC 2024: ${fmtPct(nsShare24)}',
                  bg: const Color(0xFFFFEBEE), fg: const Color(0xFFB71C1C)),
              Badge('HC YoY (USD): ${fmtPct(nsYoY)}',
                  bg: okBg(yoyOk), fg: okFg(yoyOk)),
              Badge('Произв. ≥ Потребл.: ${prodOk ? 'Да' : 'Нет'}',
                  bg: okBg(prodOk), fg: okFg(prodOk)),
            ],
          ),

          const SizedBox(height: 12),
          const Text('Фильтр страны (топ-5, 2024)',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),

          // быстрый фильтр по странам
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: top5.map((c) {
              final name = s(c['name']);
              final friendly = b(c['friendly']);
              final bg = friendly ? Colors.teal.shade50 : Colors.red.shade50;
              final fg = friendly ? Colors.teal.shade800 : Colors.red.shade800;
              return Badge(
                name,
                bg: bg,
                fg: fg,
                onTap: () {
                  setState(() => _pickedCountry = toGeoName(name));
                  _goTo(_kGeo);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  //                              UI
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // локальный помощник для карточки страны
    Widget geoTile(Map<String, dynamic> r) {
      final name = s(r['name']);
      final share23 = n(r['share2023']);
      final share24 = n(r['share2024']);
      final dpp = share24 - share23;
      final usd23 = n(r['usd2023']);
      final usd24 = n(r['usd2024']);
      final yoy = r['yoyUsd'] as num?;
      final friendly = (r['friendly'] as bool?) ?? true;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12.withOpacity(.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: friendly ? Colors.green : Colors.pinkAccent,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            Text('${share24.toStringAsFixed(3)} %',
                style: const TextStyle(color: Colors.black54)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Доля: ${share23.toStringAsFixed(3)} → ${share24.toStringAsFixed(3)} '
                '(${dpp >= 0 ? '+' : ''}${dpp.toStringAsFixed(3)} п.п.) · '
                'Импорт: ${usd23.toStringAsFixed(0)} → ${usd24.toStringAsFixed(0)} '
                '${yoy == null ? '(н/д)' : '(${yoy >= 0 ? '+' : ''}${yoy.toStringAsFixed(2)}%)'}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ]),
      );
    }

    return FutureBuilder<void>(
      future: _init,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final rowsAll = _geoRows(top2023: geoTop23, top2024: geoTop24);
        final rows = (List<Map<String, dynamic>>.from(rowsAll)
          ..sort((a, b) => n(b['share2024']).compareTo(n(a['share2024']))))
            .take(5)
            .toList();
        final shareMap = {
          for (final r in rowsAll) toGeoName(s(r['name'])): n(r['share2024']).toDouble(),
        };
        final friendlyMap = {
          for (final r in rowsAll) toGeoName(s(r['name'])): (r['friendly'] as bool? ?? true),
        };

        final volumeTopSorted =
        ([...volumeTop]..sort((a, b) => n(b['t']).compareTo(n(a['t']))));

        final isWide = MediaQuery.of(context).size.width >= 1100;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F6FF),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            titleTextStyle: const TextStyle(
                color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w700),
            iconTheme: const IconThemeData(color: Colors.black87),
            title: Text(_L(['header', 'title'], 'Таможенно-тарифное регулирование')),
            actions: [
              _topLink('Паспорт', _kPassport),
              _topLink('Баланс рынка', _kBalance),
              _topLink('География', _kGeo),
              _topLink('Цены', _kPrice),
              _topLink('Рекомендация', _kDecision),
              const SizedBox(width: 6),
            ],
          ),
            body: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // левая колонка: СНАЧАЛА навигация, потом прослеживаемость
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _leftNav(),
                        const SizedBox(height: 16),
                        _tracePanel(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // правая колонка — экспортируемая область
                  Expanded(
                    child: RepaintBoundary(
                      key: _pdfKey,
                      child: _content(
                        rows, volumeTopSorted, shareMap, friendlyMap,
                      ),
                    ),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // на узких экранах также ставим навигацию выше панели прослеживаемости
                  _leftNav(),
                  const SizedBox(height: 12),
                  _tracePanel(),
                  const SizedBox(height: 12),

                  RepaintBoundary(
                    key: _pdfKey,
                    child: _content(
                      rows, volumeTopSorted, shareMap, friendlyMap,
                    ),
                  ),
                ],
              ),

            )
        );
      },
    );
  }

  // Контент в отдельную функцию, чтобы не дублировать для mobile/desktop
  Widget _content(
      List<Map<String, dynamic>> rows,
      List<Map<String, dynamic>> volumeTopSorted,
      Map<String, double> shareMap,
      Map<String, bool> friendlyMap,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PASSPORT
        KeyedSubtree(
          key: _kPassport,
          child: _block(
            title: _L(['passport', 'title'], 'Паспорт товара'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 4,
                  childAspectRatio: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    StatCard(label: _L(['passport','fields','name'], 'Наименование'), value: name),
                    StatCard(label: _L(['passport','fields','code'], 'Код ТН ВЭД'), value: code),
                    StatCard(label: _L(['passport','fields','tariff_current'], 'Текущая ставка'), value: '${tariff.toStringAsFixed(0)}%'),
                    StatCard(label: _L(['passport','fields','tariff_bound_wto'], 'Связанная (ВТО)'), value: '${wto.toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 10),
                InfoNote(
                  title: 'Описание',
                  text: _L(
                    ['passport','note'],
                    'Паспорт фиксирует наименование, код и тарифные рамки. Параметры используются в логике выбора меры и отражаются в прослеживаемости.',
                  ),
                ),
              ],
            ),
          ),
        ),

        // MARKET BALANCE — «пилон»
        KeyedSubtree(
          key: _kBalance,
          child: _block(
            title: _L(['balance','title'], 'Баланс рынка'),
            trailing: Row(
              children: importSeries
                  .map((e) => e['year'] as int)
                  .map((y) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Badge('$y', active: y == year, onTap: () => setState(() => year = y)),
              ))
                  .toList(),
            ),
            subtitle: _L(
              ['balance','subtitle'],
              'Импорт / Производство / Потребление — в одном столбце за выбранный год',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_stackedPillar(year)]),
                const SizedBox(height: 18),



                LayoutBuilder(
                  builder: (context, c) {
                    const spacing = 12.0;
                    const cols = 3;
                    final colW = (c.maxWidth - (cols - 1) * spacing) / cols;
                    const minHeight = 120.0; // хватает под чип + значение + YoY
                    final ar = colW / minHeight; // childAspectRatio = width / height

                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: ar,
                      children: [
                        KpiBlueCard(
                          title: 'Импорт $year',
                          value: fmtUSD(_val(year, importSeries)),
                          yoy: _yoyHint(year, importSeries),
                        ),
                        KpiBlueCard(
                          title: 'Производство $year',
                          value: fmtUSD(_val(year, productionSeries)),
                          yoy: _yoyHint(year, productionSeries),
                        ),
                        KpiBlueCard(
                          title: 'Потребление $year',
                          value: fmtUSD(_val(year, consumptionSeries)),
                          yoy: _yoyHint(year, consumptionSeries),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // GEO — только ТОП-5
        KeyedSubtree(
          key: _kGeo,
          child: _block(
            title: _L(['geo','title'], 'География импорта'),
            subtitle: _L(['geo','subtitle'],
                'Хороплет по доле стран (2024). Нажмите на страну — справа выделим её в списке.'),
            child: LayoutBuilder(
              builder: (ctx, c) {
                final isWide = c.maxWidth > 860;

                // левая часть: карта
                final mapPane = SizedBox(
                  height: isWide ? 300 : 240,
                  child: WorldChoropleth(
                    shareByCountry: shareMap,
                    friendlyByCountry: friendlyMap,
                    // просили «в 2 раза крупнее, фокус на РФ»
                    zoom: 2.4,                         // можно 2.6–2.8, если хочется ещё крупнее
                    center: const MapLatLng(60, 90),   // центр над РФ
                    onCountryTap: (name) {
                      setState(() => _pickedCountry = name);
                    },
                  ),
                );

                // правая часть: список топ-5
                Widget listPane() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    ...rows.map(_geoTile).toList(),
                    const SizedBox(height: 12),
                    InfoNote(
                      title: 'Что видно',
                      text:
                      'Совокупно по НС в 2024: ${fmtPct(nsShare24)}; динамика к 2023 в \$: ${fmtPct(nsYoY)}.',
                    ),
                  ],
                );

                // раскладка: слева карта фиксированной ширины, справа — список
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 420, child: mapPane),
                      const SizedBox(width: 16),
                      Expanded(child: listPane()),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      mapPane,
                      const SizedBox(height: 12),
                      listPane(),
                    ],
                  );
                }
              },
            ),
          ),
        ),

        // PRICES — топ-5 + «лесенка» топ-10 по тоннажу
        KeyedSubtree(
          key: _kPrice,
          child: _block(
            title: _L(['price','title'], 'Средняя контрактная цена (топ-5, 2024)'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (ctx, c) {
                    final isWide = c.maxWidth > 700;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: priceTop5.map(_priceRow).toList())),
                        const SizedBox(width: 16, height: 16),
                        Expanded(
                          child: Column(
                            children: [
                              Row(children: [
                                Expanded(
                                  child: StatCard(
                                    label: 'Мин. цена',
                                    value: '${_minPrice().round()} \$ /т',
                                    hint: s(_minHolder()['name']),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: StatCard(
                                    label: 'Макс. из топ-5',
                                    value: '${_maxPrice().round()} \$ /т',
                                    hint: s(_maxHolder()['name']),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black12.withOpacity(.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Топ по объёму импорта (тонны, 2024)', style: TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    HBarList(items: volumeTopSorted, valueKey: 't', labelKey: 'name'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                InfoNote(
                  title: _L(['price','badge'], 'Что видно'),
                  text: _L(
                    ['price','note'],
                    'Выраженная дифференциация цен по странам. При выборе меры учитываем разрыв ценовых уровней, чтобы не стимулировать неценовую конкуренцию.',
                  ),
                ),
              ],
            ),
          ),
        ),

        // DECISION
        KeyedSubtree(
          key: _kDecision,
          child: _block(
            title: _L(['decision','title'], 'Итоговая рекомендация'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.lightBlue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s(recommendation?['title']).isNotEmpty
                            ? s(recommendation?['title'])
                            : 'Повышение ставки до уровня связывания ВТО (${wto.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      ...(recommendation?['reason_points'] ?? const []).map<Widget>(
                            (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(height: 1.3)),
                              Expanded(child: Text('$r', style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (recommendation?['measures'] ??
                      const ['Установить импортную пошлину в рамках обязательств ВТО.'])
                      .map<Widget>((m) => Badge(m))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: StatCard(label: 'Текущий тариф', value: '${tariff.toStringAsFixed(0)}%')),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(label: 'Связанная ставка (ВТО)', value: '${wto.toStringAsFixed(0)}%')),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(label: 'Импорт 2024', value: fmtUSD(_val(2024, importSeries)))),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
