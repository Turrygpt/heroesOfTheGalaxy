#!/usr/bin/env python3
"""Десять независимых прохождений Сатурна; сохраняет метрики и полные логи."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT") or shutil.which("godot4") or shutil.which("godot"))
    parser.add_argument("--output", type=Path, help="Каталог JSON и логов; иначе временный каталог")
    parser.add_argument("--jobs", type=int, default=2, choices=range(1, 5))
    args = parser.parse_args()
    if not args.godot:
        parser.error("Укажите --godot или переменную GODOT")
    repo = Path(__file__).resolve().parent.parent
    output = (args.output or Path(tempfile.mkdtemp(prefix="saturn-playtests-"))).resolve()
    output.mkdir(parents=True, exist_ok=True)

    def run(index: int) -> dict:
        log = output / f"run-{index + 1:02d}.log"
        # Каждый процесс получает отдельный профиль: пользовательский сейв не меняется.
        with tempfile.TemporaryDirectory(prefix="saturn-profile-") as profile:
            env = dict(os.environ, XDG_DATA_HOME=profile, APPDATA=profile, LOCALAPPDATA=profile)
            with log.open("w", encoding="utf-8") as stream:
                try:
                    completed = subprocess.run(
                        [args.godot, "--headless", "--path", str(repo), "--script",
                         "res://tools/test_saturn_playtests.gd", "--",
                         f"--profile={index // 2}", f"--seed={101 + index * 37}"],
                        env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=180,
                    )
                    status = completed.returncode
                except subprocess.TimeoutExpired:
                    status = 124
        rows = [line.removeprefix("PLAYTEST_JSON ") for line in log.read_text(encoding="utf-8").splitlines()
                if line.startswith("PLAYTEST_JSON ")]
        result = json.loads(rows[-1]) if rows else {"won": False, "error": "Нет итоговых метрик"}
        result.update(run=index + 1, exit_code=status)
        result["won"] = bool(result["won"] and status == 0)
        return result

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(run, range(10)))
    (output / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for row in results:
        print(f'{row["run"]:2d}. {row.get("route", "Ошибка")}: '
              f'{"ПОБЕДА" if row["won"] else "СБОЙ"}, сол {row.get("days", "—")}, '
              f'боёв {row.get("battles", "—")}, артефактов {row.get("artifacts", "—")}')
    passed = sum(row["won"] for row in results)
    print(f"Побед: {passed}/10. Логи и метрики: {output}")
    return 0 if passed == 10 else 1


if __name__ == "__main__":
    raise SystemExit(main())
