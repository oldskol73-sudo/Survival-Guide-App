// Sanity checks for lib/maps/pmtiles.dart that need no network:  dart run tool/pmtiles_selfcheck.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:survival_node_mobile/maps/pmtiles.dart';

int failures = 0;
void check(bool ok, String what) {
  if (!ok) failures++;
  stdout.writeln('${ok ? 'ok  ' : 'FAIL'} $what');
}

void main() {
  // Values from the PMTiles spec: zoom 0 is id 0; zoom 1 runs (0,0) (0,1) (1,1) (1,0) as ids 1..4.
  check(zxyToTileId(0, 0, 0) == 0, 'z0 -> 0');
  check(zxyToTileId(1, 0, 0) == 1, 'z1 (0,0) -> 1');
  check(zxyToTileId(1, 0, 1) == 2, 'z1 (0,1) -> 2');
  check(zxyToTileId(1, 1, 1) == 3, 'z1 (1,1) -> 3');
  check(zxyToTileId(1, 1, 0) == 4, 'z1 (1,0) -> 4');
  check(zxyToTileId(2, 0, 0) == 5, 'z2 (0,0) -> 5');

  // Round trip every tile through zoom 8, and check ids are a dense, unique 0..N-1 range.
  var good = true;
  final seen = <int>{};
  for (var z = 0; z <= 8 && good; z++) {
    for (var x = 0; x < (1 << z) && good; x++) {
      for (var y = 0; y < (1 << z); y++) {
        final id = zxyToTileId(z, x, y);
        final back = tileIdToZxy(id);
        if (back[0] != z || back[1] != x || back[2] != y || !seen.add(id)) {
          good = false;
          stdout.writeln('  mismatch at $z/$x/$y id=$id back=$back');
          break;
        }
      }
    }
  }
  check(good, 'round trip + unique ids, zoom 0..8');
  check(seen.length == (((1 << 18) - 1) ~/ 3) && seen.reduce((a, b) => a > b ? a : b) == seen.length - 1, 'ids dense 0..${seen.length - 1}');
  check(tileIdToZxy(zxyToTileId(14, 4773, 6280)).join('/') == '14/4773/6280', 'round trip at zoom 14');
  check(tileIdToZxy(zxyToTileId(15, 9000, 12000)).join('/') == '15/9000/12000', 'round trip at zoom 15');

  // Directory decoding: 2 entries; ids 5,7; runs 1,2; lengths 100,50; offsets 1 -> 0, 0 -> contiguous (100).
  final dir = Uint8List.fromList([2, 5, 2, 1, 2, 100, 50, 1, 0]);
  final e = decodeDirectory(dir);
  check(e.length == 2 && e[0].tileId == 5 && e[1].tileId == 7, 'directory ids');
  check(e[0].runLength == 1 && e[1].runLength == 2, 'directory run lengths');
  check(e[0].length == 100 && e[1].length == 50, 'directory lengths');
  check(e[0].offset == 0 && e[1].offset == 100, 'directory offsets (0 = contiguous)');

  // Multi-byte varint: 300 = 0xAC 0x02.
  final big = decodeDirectory(Uint8List.fromList([1, 0xAC, 0x02, 1, 7, 1]));
  check(big[0].tileId == 300 && big[0].length == 7 && big[0].offset == 0, 'multi-byte varint');

  // Selection counts: world at zoom 2 is 16 tiles; one tile-sized box at zoom 3 is 1 tile.
  final world = TileSelection(west: -179.9, south: -80, east: 179.9, north: 80, minZoom: 2, maxZoom: 2);
  check(world.tileCount == 16 && world.buildIds().length == 16, 'world at z2 = 16 tiles');

  stdout.writeln(failures == 0 ? '\nall checks passed' : '\n$failures check(s) FAILED');
  exit(failures == 0 ? 0 : 1);
}
