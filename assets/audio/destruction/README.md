# Звук гибели крупного корабля

`flagship_boom.mp3` — дополнительный звук, накладывается поверх обычного
процедурного взрыва (`ProceduralSfx.play_destroyed`) при уничтожении корабля
tier VI-VII (крупные пиратские/оркские корабли — см. `scripts/sample_sfx.gd:play_flagship_boom`,
вызывается из `tactical_battle.gd:_start_destruction`).

Файла может не быть — тогда для таких кораблей звучит только обычный процедурный
взрыв, ошибки нет.

Промпт для генерации через ElevenLabs (Sound Effects):

> Massive deep explosion boom, sub-bass impact with metal debris shower, epic capital
> ship destruction, punchy and short, no music
