# Стингеры победы/поражения

Сюда кладутся короткие звуковые "стингеры", играющие один раз при завершении
тактического боя (см. `scripts/sample_sfx.gd:play_victory`/`play_defeat`,
вызывается из `tactical_battle.gd:_check_battle_end`).

- `victory.mp3` — при победе игрока.
- `defeat.mp3` — при поражении игрока.
- Файла может не быть — тогда бой завершается без стингера, ошибки нет.

Промпты для генерации через ElevenLabs (Sound Effects):

| Файл | Промпт |
|---|---|
| `victory.mp3` | Triumphant short sci-fi fanfare stinger, brass and synth hybrid, heroic and brief, no vocals, 2-3 seconds |
| `defeat.mp3` | Somber short sci-fi defeat stinger, descending low synth tone with a faint alarm undertone, no vocals, 2-3 seconds |
