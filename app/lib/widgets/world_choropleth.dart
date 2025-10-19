import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:flutter/foundation.dart' show mapEquals;

class WorldChoropleth extends StatefulWidget {
  final Map<String, double> shareByCountry;   // "China": 28.3, ...
  final Map<String, bool> friendlyByCountry;  // "China": true/false
  final void Function(String country)? onCountryTap;

  // управление видом
  final double zoom;
  final MapLatLng center;

  // путь и поле имени в GeoJSON
  final String assetPath;
  final String shapeNameField;

  const WorldChoropleth({
    super.key,
    required this.shareByCountry,
    required this.friendlyByCountry,
    this.onCountryTap,
    this.zoom = 2.4,                                 // крупнее
    this.center = const MapLatLng(61, 105),          // фокус на РФ/Евразию
    this.assetPath = 'assets/maps/world.geojson',
    this.shapeNameField = 'name',                    // если в файле ADMIN → поменяй
  });

  @override
  State<WorldChoropleth> createState() => _WorldChoroplethState();
}

class _WorldChoroplethState extends State<WorldChoropleth> {
  MapZoomPanBehavior? _zoom;
  MapShapeSource? _src;
  late List<String> _countries;
  //final MapShapeLayerController _layerController = MapShapeLayerController(); // ←
  int _selectedIndex = -1;
  late final double _maxAbs;


  @override
  void initState() {
    super.initState();

    _countries = widget.shareByCountry.keys.toList();
    final maxShare = widget.shareByCountry.values.fold<double>(0.0, (m, v) => v > m ? v : m);
    _maxAbs = maxShare <= 0 ? 1.0 : maxShare;

    _zoom = MapZoomPanBehavior(
      zoomLevel: widget.zoom,
      focalLatLng: widget.center,
      enableDoubleTapZooming: true,
      enablePanning: true,
      enablePinching: true,
    );
  }

  bool _sourceBuiltOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sourceBuiltOnce) {
      _buildSource();
      _sourceBuiltOnce = true;
    }
  }

  @override
  void didUpdateWidget(covariant WorldChoropleth oldWidget) {
    super.didUpdateWidget(oldWidget);

    final dataChanged =
        !mapEquals(oldWidget.shareByCountry, widget.shareByCountry) ||
            !mapEquals(oldWidget.friendlyByCountry, widget.friendlyByCountry);

    final sourceChanged =
        oldWidget.assetPath != widget.assetPath ||
            oldWidget.shapeNameField != widget.shapeNameField;

    if (dataChanged || sourceChanged) {
      _countries = widget.shareByCountry.keys.toList();

      final maxShare = widget.shareByCountry.values.fold<double>(0.0,
              (m, v) => v > m ? v : m);
      _maxAbs = maxShare <= 0 ? 1.0 : maxShare;

      _buildSource();
    }
  }



  List<MapColorMapper> _colorMappers() {
    final steps = List<double>.generate(6, (i) => _maxAbs * i / 5.0);
    const blues = [Color(0xFFD9E8FF), Color(0xFFB9D2FF), Color(0xFF86B3FF), Color(0xFF4C8DFF), Color(0xFF1E70E6)];
    const pinks = [Color(0xFFFFD7E2), Color(0xFFFFB3C7), Color(0xFFFF96B2), Color(0xFFFF6B96), Color(0xFFE6407A)];

    final m = <MapColorMapper>[];
    for (var i = 0; i < 5; i++) {
      final from = -steps[i + 1];
      final to = -(i == 0 ? 0.0001 : steps[i]);
      m.add(MapColorMapper(from: from, to: to, color: pinks[i]));
    }
    for (var i = 0; i < 5; i++) {
      final from = (i == 0 ? 0.0001 : steps[i]);
      final to = steps[i + 1];
      m.add(MapColorMapper(from: from, to: to, color: blues[i]));
    }
    return m;
  }
  Future<void> _buildSource() async {
    try {
      await rootBundle.loadString(widget.assetPath);

      final src = MapShapeSource.asset(
        widget.assetPath,
        shapeDataField: widget.shapeNameField,
        dataCount: _countries.length,
        primaryValueMapper: (int i) => _countries[i],
        shapeColorValueMapper: (int i) {
          final name = _countries[i];
          final share = widget.shareByCountry[name] ?? 0.0;
          final friendly = widget.friendlyByCountry[name] ?? true;
          return friendly ? share : -share;
        },
        shapeColorMappers: _colorMappers(),
      );

      if (!mounted) return;

      // 👉 вот здесь — установка источника
      setState(() => _src = src);

      // 👇 а вот это вставляем сразу после
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // лёгкий «пинок»: заставляем Flutter перерисовать карту
        setState(() {});
        // или если хочешь чуть надёжнее:
        // _zoom!.zoomLevel = _zoom!.zoomLevel + 0.0001;
      });
    } catch (e) {
      debugPrint('WorldChoropleth: cannot load ${widget.assetPath}: $e');
      if (!mounted) return;
      setState(() => _src = null);
    }
  }


  @override
  Widget build(BuildContext context) {
    // скелет, пока ассет грузится/нет источника
    if (_src == null) {
      return _skeleton();
    }

    // безопасное выделение
    final hasData = _countries.isNotEmpty;
    final selected = hasData ? math.max(0, math.min(_selectedIndex, _countries.length - 1)) : -1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: const Color(0xFFF6F9FF),
        child: SfMaps(
          key: ValueKey('${widget.assetPath}:${widget.shapeNameField}'), // помогает после hot restart/web reload
          layers: [
            MapShapeLayer(
              source: _src!,
              color: const Color(0xFFE7ECF7),
              strokeColor: Colors.white,
              strokeWidth: 0.7,

              legend: MapLegend.bar(
                MapElement.shape,
                position: MapLegendPosition.bottom,
                segmentSize: const Size(24, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                overflowMode: MapLegendOverflowMode.wrap,
                textStyle: const TextStyle(
                  fontSize: 0,
                  color: Colors.transparent,
                  height: 0,
                ),
              ),

              zoomPanBehavior: _zoom,

              selectedIndex: selected,
              selectionSettings: const MapSelectionSettings(
                color: Colors.transparent,
                strokeColor: Color(0xFF0D5FE5),
                strokeWidth: 2,
              ),
              onSelectionChanged: (int index) {
                setState(() => _selectedIndex = index);
                if (hasData) widget.onCountryTap?.call(_countries[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeleton() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF6F9FF),
      borderRadius: BorderRadius.circular(14),
    ),
  );
}
