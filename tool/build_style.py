"""Generates assets/maps/style.json for the Protomaps basemap tile schema (layers: earth, landcover, landuse,
water, buildings, roads, boundaries, places, pois). Run:  python tool/build_style.py

The style is dark forest green with a cream accent to match the app. No sprite sheet is bundled, so map
symbols are drawn as circles with text labels. Fonts: only "Noto Sans Regular" glyphs ship with the app.
"""
import json

S = 'pm'
FONT = ['Noto Sans Regular']
BG = '#0A1511'
LAND = '#0F2219'
CREAM = '#EDE7DB'
NAME = ['coalesce', ['get', 'name:en'], ['get', 'name']]


def zoom(*pairs):
    return ['interpolate', ['linear'], ['zoom'], *pairs]


def layer(id, type, source_layer=None, **kw):
    d = {'id': id, 'type': type}
    if source_layer:
        d['source'] = S
        d['source-layer'] = source_layer
    d.update(kw)
    return d


def label(size, color=CREAM, layout=None):
    lay = {'text-field': NAME, 'text-font': FONT, 'text-size': size, 'text-max-width': 8}
    if layout:
        lay.update(layout)
    paint = {'text-color': color, 'text-halo-color': BG, 'text-halo-width': 1.4}
    return lay, paint


layers = [
    layer('background', 'background', paint={'background-color': BG}),
    layer('earth', 'fill', 'earth', paint={'fill-color': LAND}),
    layer('landcover', 'fill', 'landcover', paint={'fill-color': [
        'match', ['get', 'kind'],
        'forest', '#133421', 'grassland', '#12301f', 'scrub', '#13301f', 'farmland', '#11281c',
        'barren', '#1b2d25', 'glacier', '#223d3a', 'urban_area', '#0f2118', LAND]}),
    layer('landuse', 'fill', 'landuse', minzoom=5, paint={'fill-opacity': 0.9, 'fill-color': [
        'match', ['get', 'kind'],
        ['park', 'national_park', 'nature_reserve', 'forest', 'wood', 'grassland', 'garden', 'golf_course',
         'recreation_ground', 'playground', 'pitch'], '#173f27',
        ['hospital'], '#3a1f22',
        ['industrial', 'railway', 'military'], '#1a2823',
        ['school', 'university', 'college'], '#1a3128',
        ['cemetery'], '#16301f',
        '#112a1d']}),
    layer('water', 'fill', 'water', filter=['==', ['geometry-type'], 'Polygon'],
          paint={'fill-color': '#0f4468', 'fill-outline-color': '#2a7fb5'}),
    layer('waterway', 'line', 'water', minzoom=8,
          filter=['in', ['get', 'kind'], ['literal', ['river', 'stream', 'canal', 'drain', 'ditch']]],
          paint={'line-color': '#2f7fb5', 'line-width': zoom(8, 0.4, 14, 2.2)}),
    layer('buildings', 'fill', 'buildings', minzoom=13,
          paint={'fill-color': '#21493a', 'fill-outline-color': '#33705a'}),
    layer('boundaries', 'line', 'boundaries', minzoom=2,
          paint={'line-color': '#9b8f6a', 'line-width': zoom(2, 0.5, 10, 1.4), 'line-dasharray': [3, 2], 'line-opacity': 0.8}),
    layer('rail', 'line', 'roads', minzoom=10, filter=['==', ['get', 'kind'], 'rail'],
          paint={'line-color': '#6b7b70', 'line-width': zoom(10, 0.5, 16, 1.6), 'line-dasharray': [4, 3]}),
    layer('road-path', 'line', 'roads', minzoom=13, filter=['in', ['get', 'kind'], ['literal', ['path', 'other']]],
          paint={'line-color': '#8fa592', 'line-width': zoom(13, 0.5, 17, 1.6), 'line-dasharray': [2, 2]}),
    layer('road-minor', 'line', 'roads', minzoom=11, filter=['==', ['get', 'kind'], 'minor_road'],
          layout={'line-cap': 'round'}, paint={'line-color': '#58806a', 'line-width': zoom(11, 0.4, 14, 1.6, 18, 8)}),
    layer('road-medium', 'line', 'roads', minzoom=9, filter=['==', ['get', 'kind'], 'medium_road'],
          layout={'line-cap': 'round'}, paint={'line-color': '#a3a781', 'line-width': zoom(9, 0.5, 14, 2.4, 18, 12)}),
    layer('road-major', 'line', 'roads', minzoom=6, filter=['==', ['get', 'kind'], 'major_road'],
          layout={'line-cap': 'round'}, paint={'line-color': '#d9c58a', 'line-width': zoom(6, 0.6, 14, 3.2, 18, 16)}),
    layer('road-highway', 'line', 'roads', minzoom=4, filter=['==', ['get', 'kind'], 'highway'],
          layout={'line-cap': 'round'}, paint={'line-color': '#f2b45a', 'line-width': zoom(4, 0.8, 14, 4, 18, 20)}),
]

lay, paint = label(zoom(11, 10, 16, 12), color='#cfc8ad', layout={'symbol-placement': 'line', 'text-letter-spacing': 0.05})
layers.append(layer('road-labels', 'symbol', 'roads', minzoom=12,
                    filter=['in', ['get', 'kind'], ['literal', ['highway', 'major_road', 'medium_road', 'minor_road']]],
                    layout=lay, paint=paint))

lay, paint = label(zoom(8, 10, 14, 13), color='#7fb8e0')
layers.append(layer('water-labels', 'symbol', 'water', minzoom=8,
                    filter=['all', ['has', 'name'], ['==', ['geometry-type'], 'Polygon']], layout=lay, paint=paint))

# Survival points of interest. Circles because no icon sprite is bundled.
layers.append(layer('poi-water', 'circle', 'pois', minzoom=11, filter=['==', ['get', 'kind'], 'drinking_water'],
                    paint={'circle-radius': zoom(11, 3, 16, 6), 'circle-color': '#3fa7e0', 'circle-stroke-color': CREAM, 'circle-stroke-width': 1.2}))
layers.append(layer('poi-hospital', 'circle', 'pois', minzoom=10, filter=['==', ['get', 'kind'], 'hospital'],
                    paint={'circle-radius': zoom(10, 3, 16, 7), 'circle-color': '#e0524a', 'circle-stroke-color': CREAM, 'circle-stroke-width': 1.2}))
layers.append(layer('poi-peak', 'circle', 'pois', minzoom=11, filter=['==', ['get', 'kind'], 'peak'],
                    paint={'circle-radius': zoom(11, 2.5, 16, 5), 'circle-color': CREAM, 'circle-stroke-color': BG, 'circle-stroke-width': 1}))
lay, paint = label(11, layout={'text-offset': [0, 1.1], 'text-anchor': 'top', 'text-optional': True})
layers.append(layer('poi-labels', 'symbol', 'pois', minzoom=12,
                    filter=['in', ['get', 'kind'], ['literal', ['drinking_water', 'hospital', 'peak']]], layout=lay, paint=paint))

lay, paint = label(zoom(10, 10, 16, 13), color='#c9d8c9')
layers.append(layer('place-neighbourhood', 'symbol', 'places', minzoom=12,
                    filter=['in', ['get', 'kind'], ['literal', ['neighbourhood', 'macrohood']]], layout=lay, paint=paint))
lay, paint = label(zoom(6, 11, 10, 15, 14, 20))
lay['symbol-sort-key'] = ['get', 'sort_key']
layers.append(layer('place-locality', 'symbol', 'places', minzoom=6, filter=['==', ['get', 'kind'], 'locality'], layout=lay, paint=paint))
lay, paint = label(zoom(3, 11, 8, 16), color='#e8dfc4', layout={'text-transform': 'uppercase', 'text-letter-spacing': 0.08})
layers.append(layer('place-region', 'symbol', 'places', minzoom=4, maxzoom=9, filter=['==', ['get', 'kind'], 'region'], layout=lay, paint=paint))
lay, paint = label(zoom(1, 11, 6, 18), color='#f2ecd8', layout={'text-transform': 'uppercase', 'text-letter-spacing': 0.1})
layers.append(layer('place-country', 'symbol', 'places', minzoom=2, maxzoom=7, filter=['==', ['get', 'kind'], 'country'], layout=lay, paint=paint))

style = {
    'version': 8,
    'name': 'Survival Node (Protomaps schema, offline)',
    'glyphs': '__GLYPHS__',
    'sources': {S: {'type': 'vector', 'tiles': ['__TILES__'], 'minzoom': 0, 'maxzoom': 14,
                    'attribution': '© OpenStreetMap contributors (ODbL), Natural Earth'}},
    'layers': layers,
}
with open('assets/maps/style.json', 'w', encoding='utf-8') as f:
    json.dump(style, f, indent=1, ensure_ascii=False)
print(len(layers), 'layers written')
