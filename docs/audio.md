# Звук, музыка и фон главного меню

Из `AGENTS.md` сюда ушла звуковая часть раздела 8 — читай, когда трогаешь
музыку экранов, кроссфейды или слоёный фон меню.

---

Звук: процедурный боевой SFX (`procedural_sfx.gd`, шина `SFX`) и фоновая
музыка на 4 экранах с плавным
кроссфейдом между собой (`AudioStreamPlayer` на шине `Music` через `GameSettings.attach_music`
+ `Tween` на `volume_db` плеера, длительность перехода —
`MUSIC_FADE_DURATION`/`BATTLE_MUSIC_FADE_DURATION` в соответствующем файле).
Громкость шин (общая/музыка/эффекты) крутится в меню по Esc и не мешает фейдам:

| Экран | Трек | Где живёт |
|---|---|---|
| Главное меню | случайный из `music/main_menu/` | `main_menu.gd:_start_music` |
| Глобальная карта | случайный из `music/map/` | `space_strategy_map.gd:_start_music/pause_music/resume_music` |
| Тактический бой | случайный из `music/battle/` | `tactical_battle.gd:_start_music/_fade_out_and_release_music` |
| Экран планеты людей | `music/Human Castle.mp3` | `human_planet_screen.gd:_start_music/fade_out_music` |

Все экраны, кроме планеты людей, берут трек не жёстко зашитым: код сканирует
папку (`music/main_menu/`, `music/map/` или `music/battle/`, см. `README.md`
в каждой) и берёт случайный mp3 при входе на экран. Карта и бой поверх этого
ещё и кроссфейдят громкость уже выбранного трека между собой при переходе
карта↔бой (`MUSIC_FADE_DURATION`/`BATTLE_MUSIC_FADE_DURATION`) — сам выбор
трека кроссфейд не трогает, он происходит один раз при входе. У меню фейдов
нет вовсе. Пустая папка нигде не ломает экран — просто нет музыки
(`pause_music`/`resume_music` в `space_strategy_map.gd` это тоже учитывают
через `is_instance_valid(music_player)`).

Фон главного меню собирается из вырезанных частей стартового кадра
(`assets/ui/main_menu_layers/`: планета, кольцо, луны, астероиды, логотип)
поверх процедурного космоса с туманностями и звёздами — `menu_space_backdrop.gd`
и шейдер `shaders/menu_space.gdshader`. Название игры — слой `logo.png`,
отдельным `Label` оно не дублируется. Папка `assets/ui/main_menu_backgrounds/`
остаётся фолбэком, если слоёв нет; пустая папка без слоёв даёт старый плоский
фон со звёздами.

При входе в бой/на планету затухает музыка карты (`pause_music()`), при
выходе — плавно возвращается (`resume_music()`); трек уходящего экрана в это
время фейдится сам через свою `fade_out_music`/`_fade_out_and_release_music`,
которая **переносит `AudioStreamPlayer` в `get_tree().root`** перед
`queue_free()` родительской сцены — иначе `Tween` вместе с ним умрёт
недоиграв. Озвучки UI по-прежнему нет.
`data/ship_configs/` пустой — редактор кораблей (F8) ещё ничего не сохранял.
