# Звуки каста боевых протоколов

Сюда кладутся звуки активации протоколов героя (см. `scripts/sample_sfx.gd:play_protocol_cast`
и `scripts/hero_protocols.gd` — 14 протоколов в 4 школах).

- Один файл на школу — обязательный минимум: `engineering_cast.mp3`, `tactics_cast.mp3`,
  `ew_cast.mp3`, `weapons_cast.mp3`. Уже сгенерированы через ElevenLabs Sound Effects
  и лежат в этой папке.
- Опционально — переопределение под конкретный протокол по его id из
  `hero_protocols.gd:PROTOCOLS` (например `repair_swarm.mp3`, `orbital_strike.mp3`):
  если такой файл есть, он проигрывается вместо звука школы.
- Файл может отсутствовать — тогда каст просто без звука (только визуальный эффект),
  ошибки не будет (см. `ResourceLoader.exists` в `sample_sfx.gd`).

Промпты для генерации через ElevenLabs (Sound Effects, "Describe impact"):

| Файл | Промпт |
|---|---|
| `engineering_cast.mp3` | Soft mechanical whirring with a bright synthetic chime, repair nanobots activating, gentle sci-fi energy hum, short one-shot, no music |
| `tactics_cast.mp3` | Quick sci-fi warp blink, a sharp whoosh with a metallic doppler shift, tactical targeting beep underneath, short one-shot, no music |
| `ew_cast.mp3` | Electronic jamming static burst, glitchy digital interference crackle with a descending pitch zap, short one-shot, no music |
| `weapons_cast.mp3` | Heavy sci-fi energy weapon charge-up and release, deep orbital cannon hum with a sharp electric crack, short one-shot, no music |

Опциональные переопределения по id протокола — тот же принцип, промпт под конкретное
умение (например `repair_swarm`: "Small drone swarm whirring, quick repair clicks and
a soft mechanical hum, short one-shot"; `orbital_strike`: "Heavy orbital cannon strike,
deep bass charge-up into a thunderous impact, short one-shot").
