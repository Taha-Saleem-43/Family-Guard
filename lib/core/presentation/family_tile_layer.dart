import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/map_tile_client.dart';

/// Owns one provider per map, avoiding replacement/disposal on widget rebuilds.
class FamilyTileLayer extends StatefulWidget {
  const FamilyTileLayer({super.key, this.tileProvider});
  final TileProvider? tileProvider;

  @override
  State<FamilyTileLayer> createState() => _FamilyTileLayerState();
}

class _FamilyTileLayerState extends State<FamilyTileLayer> {
  late final _provider =
      widget.tileProvider ?? NetworkTileProvider(httpClient: MapTileClient());
  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'FamilyGuard',
    tileProvider: _provider,
    maxNativeZoom: 19,
    panBuffer: 0,
  );
}
