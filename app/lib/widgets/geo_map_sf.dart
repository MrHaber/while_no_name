// lib/widgets/world_choropleth.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';

class WorldChoropleth extends StatefulWidget {
  final Map<String, double> shareByCountry;     // доля в 2024 (0..100)
  final Map<String, bool> friendlyByCountry;    // true = дружественная
  final String? selectedCountry;                // имя для внешней подсветки
  final ValueChanged<String?>? onCountryTap;    // колбэк при тапе

  const WorldChoropleth({
    super.key,
    required this.shareByCountry,
    required this.friendlyByCountry,
    this.selectedCountry,
    this.onCountryTap,
  });

  @override
  State<WorldChoropleth> createState() => _WorldChoroplethState();
}

class _WorldChoroplethState extends State<WorldChoropleth> {
  late MapShapeSource _source;
  late List<String> _countries;     // порядок соответствует dataCount
  late double _maxShare;
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();

    // подготовим последовательность стран и максимум
    _countries = widget.shareByCountry.keys.toList();
    _countries.sort(); // стабильный порядок

    _maxShare = 0;
    for (final v in widget.shareByCountry.values) {
      if (v > _maxShare) _maxShare = v;
    }

    // если снаружи уже задана выбранная страна — выставим индекс
    if (widget.selectedCountry != null) {
      _selectedIndex = _countries.indexOf(widget.selectedCountry!);
      if (_selectedIndex! < 0) _selectedIndex = 0;
    }

    _source = MapShapeSource.asset(
      'assets/maps/world.geojson',                 // см. pubspec ниже
      shapeDataField: 'name',                   // поле с названием страны в GeoJSON
      dataCount: _countries.length,
      primaryValueMapper: (int i) => _countries[i],
      shapeColorValueMapper: (int i) =>
      widget.shareByCountry[_countries[i]] ?? 0.0,
      shapeColorMappers: _buildColorMappers(),
    );
  }

  @override
  void didUpdateWidget(covariant WorldChoropleth old) {
    super.didUpdateWidget(old);
    // синхронизируем выбранную страну, если её меняют извне
    if (widget.selectedCountry != old.selectedCountry) {
      final idx = widget.selectedCountry == null
          ? null
          : _countries.indexOf(widget.selectedCountry!);
      setState(() => _selectedIndex = (idx != null && idx >= 0) ? idx : 0);
    }
  }

  List<MapColorMapper> _buildColorMappers() {
    // 6 опорных точек (0%..max) → 5 промежутков
    final steps = (_maxShare <= 0)
        ? List<double>.generate(6, (i) => i.toDouble())
        : List<double>.generate(6, (i) => _maxShare * i / 5.0);

    const colors = [
      Color(0xFFEFF6FF),
      Color(0xFFD9E8FF),
      Color(0xFFB9D2FF),
      Color(0xFF86B3FF),
      Color(0xFF4C8DFF),
      Color(0xFF1E70E6),
    ];
    return List<MapColorMapper>.generate(5, (i) {
      final from = steps[i];
      final to = steps[i + 1] == 0 ? 0.0001 : steps[i + 1];
      return MapColorMapper(from: from, to: to, color: colors[i + 1]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF6F8FC),
        child: SfMaps(
          layers: [
            MapShapeLayer(
              source: _source,

              // Выбор: в новых версиях просто задаём колбэк + selectedIndex
              selectedIndex: _selectedIndex,
              onSelectionChanged: (int index) {
                setState(() => _selectedIndex = index);
                widget.onCountryTap?.call(_countries[index]);
              },

              // Внешняя подсветка дружественных/недружественных в тултипе
              tooltipSettings: const MapTooltipSettings(color: Colors.white),
              shapeTooltipBuilder: (BuildContext ctx, int index) {
                final name = _countries[index];
                final share = widget.shareByCountry[name] ?? 0;
                final friendly = widget.friendlyByCountry[name] ?? true;
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: friendly ? Colors.green : Colors.pinkAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$name — ${share.toStringAsFixed(2)} %',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                );
              },

              // Стиль выделения (MapSelectionSettings есть, но без enable)
              selectionSettings: const MapSelectionSettings(
                color: Color(0x661E70E6),
                strokeColor: Color(0xFF1E70E6),
                strokeWidth: 2,
              ),

              strokeColor: Colors.white,
              strokeWidth: 0.5,
            ),
          ],
        ),
      ),
    );
  }
}
