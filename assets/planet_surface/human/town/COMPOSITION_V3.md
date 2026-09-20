# Цельная панорама Земли v3

Встроенный ImageGen, два последовательных шага: сначала весь город, затем удаление зданий из того же рисунка. Файлы находятся рядом с этим документом:

- master_v3.png — цельный город со всеми 12 объектами.
- clean_plate_v3.png — пробная подложка без основных зданий, с сохранёнными террасами и дорогами.

20.09.2026 добавлены согласованные стадии `basic_v4.png`, `middle_v4.png` и
`advanced_v4.png`. Они дают отдельный силуэт совету I–III, академии I–III и
обычным версиям пяти верфей; максимальная стадия по-прежнему использует
`master_v3.png`. Форт использует участок исходной панорамы. Отдельные
ракетные батареи и программный купол отключены: полностью построенный город
должен совпадать с эталонной картинкой без дополнительных наложений.

Для ручного тестирования включён `FREE_CONSTRUCTION_TEST` в
`scripts/human_planet_town.gd`: все здания и улучшения бесплатны на Земле,
Марсе и у Торговой лиги. Требования и одна стройка в сол сохранены.

Подключено в HumanPlanetTown для «Новой игры». Участки исходника накладываются по полигонам из human_town_composition.gd. Проверены начальная, промежуточная и полная застройки. Генеративное удаление не гарантирует идентичные пиксели вне зданий. Небо пока нарисовано; отдельное программное небо и локальные визуальные варианты уровней остаются следующими этапами.

## План игровой разборки

1. Зафиксировать master как эталон: камера, размеры холста, террасы и положение каждого здания больше не меняются.
2. Для каждого здания подготовить маску области со зданием, его собственной тенью и местом примыкания к земле. Брать цветные пиксели из master, а не генерировать здание заново в другом ракурсе. Общие дороги и подпорные стены остаются частью постоянного города.
3. За маской разместить локальный clean plate. Проверять края по исходнику: нельзя просто наложить прямоугольники из двух слегка различающихся изображений.
4. Все слои используют один холст и одно преобразование. Без индивидуального центрирования и масштабирования по прозрачным границам — иначе композиция опять расползётся.
5. Ближние деревья, камни, парапеты выделить отдельным верхним слоем. Если силуэты перекрываются, хранить явный порядок от дальних к ближним.
6. Совет I–IV, университет I–IV, пять производств I–II рисовать локальными правками внутри закреплённых областей. Меняется архитектура, но не площадка, ракурс или направление света. Контактные тени входят в эти варианты.
7. Состояние построено/не построено переключает маску, уровень — локальный вариант. Существующая экономика HumanPlanetScreen остаётся источником требований, стоимости, найма и сохранений. Отдельная маска клика исключает попадание через передние объекты.
8. Проверить снимками пустую колонию, промежуточное развитие и максимальный город: последний должен восстанавливать исходную master-композицию.

## Промпт master

Use case: stylized-concept. Asset type: complete human planet TOWN SCREEN master painting for a space strategy inspired by Heroes of Might and Magic III. Generate a finished coherent richly illustrated city panorama, NOT isolated sprites scattered on empty grass. Landscape 16:9, high detail. Elevated three-quarter fixed camera overlooking a flourishing human sci-fi colony embedded in lush green terraced hills, rock cliffs, a distant turquoise bay and mountains. A grand central planetary council palace with ivory stone, blue steel and gold accents anchors the composition. Winding paved streets, stairs, retaining walls, garden courtyards, aqueduct-like utility conduits and connected landing aprons organically bind the town; no empty uniform field. Twelve readable major buildings ALL visible as parts of ONE PAINTING: 1 central towering council palace; 2 blue luminous ring shield generator on a rear ridge; 3 compact missile defense battery on another ridge; 4 fighter hangar with tiny fighters and apron on left middle terrace; 5 heavier assault craft hangar lower left; 6 corvette base on right middle terrace; 7 frigate shipyard with long spacecraft and cranes upper right; 8 destroyer assembly yard with a larger spaceship and industrial gantry lower right; 9 intimate warm amber-lit officers bar with canopy near lower left road; 10 scholarly university with observatory dome and telescope lower middle-left; 11 glass-vaulted galactic exchange hall lower middle-right; 12 secure bank with blue dome and vault entry at right civic terrace. Do not add other major buildings that confuse these twelve, small architectural connectors fine. Varied natural silhouettes and asymmetric layered composition, buildings take up much of the frame, not tiny icons. Buildings nestled firmly into terraces, consistent contact shadows and cast shadows sunlight from upper left, distant buildings smaller and softly hazed. Atmospheric blue sky is only top 15%. Large foreground leafy branches at upper left and rocks/shrubbery bottom corners partially overlap nearest architecture, not obscure all buildings. Classic detailed painted pre-rendered strategy game town art, inviting earthly greenery, rich texture, warm sun/cool shadow, beautiful cinematic but readable. No labels, no text, no UI, no grid, no map markers, no detached foundations, no floating objects. This will be the exact master composition subsequently separated into construction layers.

## Промпт удаления зданий

Use case: precise-object-edit. Input image is the exact master painting of a human sci-fi strategy town, edit target. Create its EMPTY CONSTRUCTION PLATE, same camera, same exact dimensions and pixel-aligned scenery. Remove ONLY these twelve major building complexes and their own spacecraft, cranes, furniture, building-specific shadows: central tall council palace; blue shield ring top left; missile battery top middle right; two hangars at left; upper right frigate yard; middle right corvette base; bottom right destroyer assembly yard; blue domed bank right; glass exchange lower center-right; telescope university lower center-left; small warm tent officers bar lower left. Replace each building volume and footprint with convincingly painted EMPTY stone/earth courtyard and underlying continuation of terrain behind it. KEEP ALL terraced cliffs, retaining walls, access roads, staircases, water cascades, paths, general garden planting, foreground rocks and framing branches, mountains, bay, distant skyline and sky at their EXACT original locations and appearance. Do not flatten the terraces, do not change any perspective, do not move the camera, do not redesign the landscape. Do not leave buildings, scaffolding, construction equipment or ruins in the twelve plots. No text, no UI. This is a clean plate to place the original building regions over with exact alignment.
