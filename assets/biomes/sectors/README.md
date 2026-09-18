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
Проверки: `test_random_campaign_layout.gd` (пять сидов),
`test_random_ice_biome.gd`, `test_campaign_map.gd`.

## Промпт атласа

Create a production game sprite atlas, stylized-concept, for Heroes of the Galaxy 2D space strategy. Exactly 6 columns by 4 rows, 24 separate sprites, each centered fully within equal grid cells with 15% transparent padding. Actual transparent background, clean alpha, no text or grid lines. Row 1: six volcanic space objects: broken black basalt moon fragment with subtle orange fissures; elongated porous asteroid ridge; three fractured dark rocks; small ember debris cloud; torn scorched engine section; thin curved orange dust ribbon. Row 2: six crystalline space objects: stone with emerald crystals; floating violet crystal shards; long mineral ridge; tiny crystal dust cluster; shattered ancient metal ring with crystals; thin teal gas ribbon. Row 3: six dead battlefield objects: torn half cruiser hull (NOT complete ship); broken engine; fractured satellite frame; independent grey metal debris cloud; ruptured cargo tanks; curved dark dust stream. Row 4: six faction wreckage clusters: clean white human panel and tank fragments; rusty pirate jagged wreckage; chunky red orc armor and engine fragments; colored trader container debris; broken antenna cluster; thin pale-blue ion gas ribbon. All freely floating in zero gravity, independently oriented fragments, no ground floor pedestal horizon common bottom edge, no intact buildings, no intact ships, no surface shadows. High quality painterly semi-realistic strategy game assets, detailed metal and stone, strong silhouettes readable small. Mostly dark desaturated material with restrained glow. Sprite sheet square 1536x1536 or larger. All cells identical dimensions, no cropping, no overlap.
