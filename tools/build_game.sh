#!/usr/bin/env sh
# Собирает игру ВМЕСТЕ с интро-роликом.
#
#   sh tools/build_game.sh                    # Windows Desktop -> build/windows/
#   sh tools/build_game.sh Web                # веб-сборка      -> build/web/
#   sh tools/build_game.sh "Windows Desktop" --no-intro   # можно и без ролика
#
# Главное, зачем нужен этот скрипт: `video/intro.ogv` НЕ лежит в гите (он
# больше лимита GitHub, см. .gitignore), а игра без него молча стартует
# сразу с карты. Поэтому сборка без файла ролика тут не тихая, а падает —
# чтобы "сборка с синематиком" действительно была с синематиком.
#
# Движок ищется так же, как в run_tests.sh: переменная GODOT, затем
# godot/godot4 в PATH, затем Godot_v*.exe в корне репозитория. Шаблоны
# экспорта должны быть установлены (в редакторе: Проект > Установить
# шаблоны экспорта).

set -u

cd "$(dirname "$0")/.." || exit 1

PRESET="Windows Desktop"
REQUIRE_INTRO=1
for arg in "$@"; do
	case "$arg" in
	--no-intro) REQUIRE_INTRO=0 ;;
	-*) echo "Неизвестный ключ: $arg" >&2; exit 2 ;;
	*) PRESET="$arg" ;;
	esac
done

INTRO="video/intro.ogv"
if [ -f "$INTRO" ]; then
	echo "Ролик: $INTRO ($(wc -c < "$INTRO") байт) — войдёт в сборку"
elif [ "$REQUIRE_INTRO" -eq 1 ]; then
	echo "Нет файла ролика $INTRO — в сборке не будет синематика." >&2
	echo "Он не хранится в гите (лимит GitHub), положи его локально в video/." >&2
	echo "Собрать всё равно: sh tools/build_game.sh \"$PRESET\" --no-intro" >&2
	exit 1
else
	echo "Ролика нет, собираем без синематика (--no-intro)."
fi

find_godot() {
	if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then printf '%s' "$GODOT"; return 0; fi
	for candidate in godot4 godot; do
		if command -v "$candidate" >/dev/null 2>&1; then printf '%s' "$candidate"; return 0; fi
	done
	for candidate in ./Godot_v*_console.exe ./Godot_v*.exe; do
		[ -f "$candidate" ] && { printf '%s' "$candidate"; return 0; }
	done
	return 1
}

GODOT_BIN=$(find_godot) || {
	echo "Движок Godot не найден." >&2
	echo "Положи Godot_v*.exe в корень репозитория, поставь godot в PATH" >&2
	echo "или укажи путь явно: GODOT=/путь/к/godot sh tools/build_game.sh" >&2
	exit 127
}

echo "Движок: $GODOT_BIN"
echo "Пресет: $PRESET"

# Импорт ресурсов отдельным шагом: в свежем клоне папки .godot/ нет, и
# экспорт без неё положит в сборку не все ресурсы.
"$GODOT_BIN" --headless --path . --import || exit 1

OUT=$(sed -n "/^name=\"$PRESET\"\$/,/^export_path=/p" export_presets.cfg | sed -n 's/^export_path="\(.*\)"$/\1/p')
[ -n "$OUT" ] || { echo "В export_presets.cfg нет пресета \"$PRESET\"." >&2; exit 2; }
mkdir -p "$(dirname "$OUT")" || exit 1

"$GODOT_BIN" --headless --path . --export-release "$PRESET" "$OUT" || exit 1

echo
echo "Готово: $OUT"
