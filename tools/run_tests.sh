#!/usr/bin/env sh
# Прогоняет все headless-тесты из tools/ одной командой.
#
#   sh tools/run_tests.sh                  # все тесты
#   sh tools/run_tests.sh orc battle       # только те, чьё имя содержит orc или battle
#
# Движок ищется автоматически: переменная GODOT, затем godot/godot4 в PATH,
# затем Godot_v*_console.exe / Godot_v*.exe в корне репозитория.
# Тест считается упавшим по ненулевому коду возврата (push_error даёт его сам).

set -u

cd "$(dirname "$0")/.." || exit 1

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
	echo "или укажи путь явно: GODOT=/путь/к/godot sh tools/run_tests.sh" >&2
	exit 127
}

echo "Движок: $GODOT_BIN"

# Ограничение времени на один тест: timeout, если он есть, иначе без него.
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
if command -v timeout >/dev/null 2>&1; then
	_run_with_timeout() { timeout "$TEST_TIMEOUT" "$@"; }
else
	_run_with_timeout() { "$@"; }
fi


FILTERS="$*"

passed=0
failed=0
failed_names=""

for script in tools/test_*.gd tools/*_regression.gd; do
	[ -f "$script" ] || continue
	name=$(basename "$script" .gd)

	if [ -n "$FILTERS" ]; then
		match=0
		for filter in $FILTERS; do
			case "$name" in *"$filter"*) match=1 ;; esac
		done
		[ "$match" -eq 1 ] || continue
	fi

	printf '  %-34s ' "$name"

	# Два теста не запускаются обычным --script:
	#   test_planet_turn_persistence — это Node, а не SceneTree, нужна сцена;
	#   test_main_menu — выходит с кодом 2, пока в пути профиля нет test_profile.
	cleanup_override=0
	case "$name" in
	test_planet_turn_persistence)
		set -- --headless --path . res://tools/PlanetTurnPersistence.tscn
		;;
	test_main_menu)
		if [ ! -f override.cfg ]; then
			{
				echo '[application]'
				echo 'config/use_custom_user_dir=true'
				echo 'config/custom_user_dir_name="heroes_test_profile"'
			} > override.cfg
			cleanup_override=1
		fi
		set -- --headless --path . --script "res://$script"
		;;
	*)
		set -- --headless --path . --script "res://$script"
		;;
	esac

	# Таймаут на тест: зависший прогон иначе держит весь набор. Зависание тут
	# обычно означает ошибку разбора — SceneTree не доходит до quit().
	if output=$(_run_with_timeout "$GODOT_BIN" "$@" 2>&1); then
		echo "ok"
		passed=$((passed + 1))
	else
		status=$?
		if [ "$status" -eq 124 ]; then
			echo "ЗАВИС (> ${TEST_TIMEOUT}s)"
		else
			echo "ПАДАЕТ"
		fi
		printf '%s\n' "$output" | tail -20 | sed 's/^/      /'
		failed=$((failed + 1))
		failed_names="$failed_names $name"
	fi

	[ "$cleanup_override" -eq 1 ] && rm -f override.cfg
done

echo
echo "прошло: $passed, упало: $failed"
[ "$failed" -eq 0 ] || { echo "упали:$failed_names"; exit 1; }
