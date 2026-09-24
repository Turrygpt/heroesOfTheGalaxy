# Оформление случайной карты

Случайная карта использует тот же рендер поясов и туманностей, что «Новая игра»:
`campaign_terrain_renderer.gd` и `shaders/campaign_hazards.gdshader`.
Геометрия генерируется отдельно: широкие газовые фронты, астероидные пояса
с проходами, открытые области и небольшие облака замедления. Карта Марса
не копируется. Проверка достижимости отбрасывает перекрывающие путь области.

`random_sector_renderer.gd` добавляет редкие акценты: не более одного у части
каменных препятствий, максимум 24 на всю карту. Размер 64–104 пикселя,
между акцентами минимум четыре клетки; возле игровых объектов их нет.
Нет прежней массовой россыпи и отдельных огромных региональных облаков.
Наборы прежних и новых пропсов сохранены, все сразу на каждой карте не навязываются.

`props.png` — атлас 6×4 (24 рисунка), создан встроенным imagegen.
Ряды 1 (лавовая порода) и 3–4 (остовы) этого же атласа берут секторы со своей
композицией из `biome_sector_defs.gd`: токсичный перекрашивает их рампой в
кислотную зелень, высокотемпературный — в раскалённый базальт. Своего арта у
них пока нет; отдельный атлас заменяется в профиле, без правок рендера.

Проверки: `test_random_campaign_layout.gd` (пять сидов),
`test_random_biome_sectors.gd`, `test_campaign_map.gd`.

## Промпт атласа

Create a production game sprite atlas, stylized-concept, for Heroes of the Galaxy 2D space strategy. Exactly 6 columns by 4 rows, 24 separate sprites, each centered fully within equal grid cells with 15% transparent padding. Actual transparent background, clean alpha, no text or grid lines. Row 1: six volcanic space objects: broken black basalt moon fragment with subtle orange fissures; elongated porous asteroid ridge; three fractured dark rocks; small ember debris cloud; torn scorched engine section; thin curved orange dust ribbon. Row 2: six crystalline space objects: stone with emerald crystals; floating violet crystal shards; long mineral ridge; tiny crystal dust cluster; shattered ancient metal ring with crystals; thin teal gas ribbon. Row 3: six dead battlefield objects: torn half cruiser hull (NOT complete ship); broken engine; fractured satellite frame; independent grey metal debris cloud; ruptured cargo tanks; curved dark dust stream. Row 4: six faction wreckage clusters: clean white human panel and tank fragments; rusty pirate jagged wreckage; chunky red bandit armor and engine fragments; colored trader container debris; broken antenna cluster; thin pale-blue ion gas ribbon. All freely floating in zero gravity, independently oriented fragments, no ground floor pedestal horizon common bottom edge, no intact buildings, no intact ships, no surface shadows. High quality painterly semi-realistic strategy game assets, detailed metal and stone, strong silhouettes readable small. Mostly dark desaturated material with restrained glow. Sprite sheet square 1536x1536 or larger. All cells identical dimensions, no cropping, no overlap.

## Промпты для атласов токсичного и высокотемпературного секторов

Оба сектора пока живут на перекрашенном общем атласе. Если понадобится свой
арт, формат тот же: PNG, сетка 4×4 равных клеток, прозрачный фон, 15% отступа
внутри клетки. Готовый файл кладётся в `assets/biomes/<имя>/props_medium.png`
и подставляется в `medium`/`berg`/`shard` профиля в `biome_sector_defs.gd`;
рампу тогда можно убрать (`"shader": "cool"` или `saturation` вместо неё).

**Токсичный.** Create a production game sprite atlas, stylized-concept, for a
2D space strategy game. Exactly 4 columns by 4 rows, 16 separate sprites, each
centered within equal grid cells with 15% transparent padding. Actual
transparent background, clean alpha, no text or grid lines. Sixteen corroded
toxic-space objects: pitted asteroid with acid-green veins; rock with bright
bio-luminescent green growth in its cracks; half-dissolved metal hull plate
with green corrosion blooms; ruptured chemical tank leaking green crust;
porous sponge-like rock; fractured rock cluster with slime sheen; eaten-away
satellite frame; barnacle-covered cargo pod; rock with a green crystalline
crust; collapsed dome section; twisted pipe tangle; broken reactor housing
with green glow; scab-like mineral plate; rock split open with glowing green
core; corroded engine bell; clump of fused debris. All freely floating in zero
gravity, independently oriented, no ground, no horizon, no common bottom edge,
no intact ships or buildings, no surface shadows. High quality painterly
semi-realistic strategy assets, detailed stone and eaten metal, strong
silhouettes readable small. Mostly dark olive and grey material with
restrained acid-green glow. Square sheet 1536x1536 or larger, all cells
identical, no cropping, no overlap.

**Высокотемпературный.** Create a production game sprite atlas,
stylized-concept, for a 2D space strategy game. Exactly 4 columns by 4 rows,
16 separate sprites, each centered within equal grid cells with 15%
transparent padding. Actual transparent background, clean alpha, no text or
grid lines. Sixteen fragments of a destroyed molten world: curved slab of
planetary crust with glowing orange fissures, clearly a piece of a much larger
sphere; another crust slab with a different curvature; black basalt boulder
with cooling magma seams; shattered mantle chunk glowing from inside; porous
scoria rock; obsidian shard; lava-crusted plate torn at both ends; blackened
rock with a bright molten core showing through a crack; ash-covered fragment
with faint embers; slag lump; cracked spherical core fragment; jagged crust
wedge; rock with lava dripping off one edge frozen in vacuum; burnt-out metal
hull plate warped by heat; scorched engine section; cluster of small glowing
cinders. All freely floating in zero gravity, independently oriented, no
ground, no horizon, no common bottom edge, no intact ships or buildings, no
surface shadows. High quality painterly semi-realistic strategy assets,
detailed basalt and glowing rock, strong silhouettes readable small. Mostly
near-black basalt with restrained orange incandescence, not uniformly bright.
Square sheet 1536x1536 or larger, all cells identical, no cropping, no
overlap.
