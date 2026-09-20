@echo off
chcp 65001 >nul
rem Сборка игры из cmd. То же, что tools/build_game.sh, только без sh.
rem
rem   tools\build_game.cmd              Windows-сборка вместе с интро-роликом
rem   tools\build_game.cmd --no-intro   собрать без ролика
rem   tools\build_game.cmd Web          веб-сборка
rem
rem Ролик video/intro.ogv в гите не лежит (лимит GitHub), поэтому без него
rem сборка не делается молча: нужен явный --no-intro. Такой сборке ролик
rem можно подложить и потом - файл intro.ogv рядом с exe игра найдёт сама.
setlocal

cd /d "%~dp0.."

set "PRESET=Windows Desktop"
set "REQUIRE_INTRO=1"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--no-intro" goto arg_no_intro
set "PRESET=%~1"
shift
goto parse_args
:arg_no_intro
set "REQUIRE_INTRO=0"
shift
goto parse_args
:args_done

if /i "%PRESET%"=="Web" goto out_web
set "OUT=build/windows/HeroesOfTheGalaxy.exe"
set "OUTDIR=build\windows"
goto out_done
:out_web
set "OUT=build/web/index.html"
set "OUTDIR=build\web"
:out_done

if exist "video\intro.ogv" goto intro_ok
if "%REQUIRE_INTRO%"=="1" goto no_intro_file
echo Ролика нет, собираем без синематика.
echo Положи intro.ogv рядом с готовым exe - игра подхватит его сама.
goto intro_done
:no_intro_file
echo Нет файла ролика video\intro.ogv - в сборке не будет синематика.
echo Он не хранится в гите, положи его локально в video\.
echo Собрать всё равно: tools\build_game.cmd --no-intro
exit /b 1
:intro_ok
echo Ролик: video\intro.ogv - войдёт в сборку
:intro_done

set "GODOT_BIN="
if defined GODOT if exist "%GODOT%" set "GODOT_BIN=%GODOT%"
if defined GODOT_BIN goto godot_found
for %%f in (Godot_v*_console.exe) do if not defined GODOT_BIN set "GODOT_BIN=%%f"
if defined GODOT_BIN goto godot_found
for %%f in (Godot_v*.exe) do if not defined GODOT_BIN set "GODOT_BIN=%%f"
if defined GODOT_BIN goto godot_found
where godot >nul 2>nul
if not errorlevel 1 set "GODOT_BIN=godot"
if defined GODOT_BIN goto godot_found
echo Движок Godot не найден.
echo Положи Godot_v*.exe в корень репозитория или укажи путь:
echo   set "GODOT=C:\путь\к\godot.exe"
exit /b 127
:godot_found

echo Движок: %GODOT_BIN%
echo Пресет: %PRESET%

rem Импорт отдельным шагом: без папки .godot экспорт положит в сборку не все
rem ресурсы.
"%GODOT_BIN%" --headless --path . --import
if errorlevel 1 exit /b 1

if not exist "%OUTDIR%" mkdir "%OUTDIR%"
"%GODOT_BIN%" --headless --path . --export-release "%PRESET%" "%OUT%"
if errorlevel 1 exit /b 1

echo.
echo Готово: %OUT%
endlocal
