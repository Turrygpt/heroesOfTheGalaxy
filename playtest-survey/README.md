# Плейтест Heroes of the Galaxy

`index.html` — страница демо и установщика. `feedback/index.html` — отдельная анкета. Общий стиль — `style.css`; вопросы и отправка — `app.js`. В `deploy/` лежат конфигурация Nginx и служба systemd.

В `screenshots/` лежат три настоящих кадра игры: стратегическая карта (`build/qa_production.png`), экран строительства Земли (`build/construction_card_final.png`) и тактический бой (снимок `tools/BattleShot.tscn`). На странице они сопровождаются описанием игрового цикла и первых действий. Полные PNG открываются по нажатию; ниже первого экрана браузер загружает их отложенно.

Анкета рассчитана на 5–10 минут. Обязательны только время игры и общая оценка; остальные вопросы можно пропускать. Свободные поля помогают понять конкретные проблемы и приоритеты исправлений.

## Анонимная сессия и ответы

`GET /playtest/api/session` выдаёт случайный cookie `hotg_playtest_sid` на 30 дней (`Secure`, `HttpOnly`, `SameSite=Lax`, область `/playtest/api`). Сервер хранит только SHA-256 хеш токена. `POST /playtest/api/submit` принимает один ответ для каждой сессии; повторная отправка возвращает HTTP 409. Ограничение действует на браузерный сеанс: другой браузер или удаление cookie позволяет ответить снова. Один общий браузер при этом не сможет отправить анкеты для нескольких людей в течение действия cookie.

Ответы сохраняются в SQLite `/var/lib/hotg-playtest/responses.sqlite3`, вне публичного каталога. В базе нет имени, IP, заголовков и времени отправки. Свободные поля просят не указывать личные данные. На `/playtest/` выключен access log Nginx; сторонняя аналитика не используется. Публичной страницы просмотра ответов нет.

При первом запуске `storage.py` переносит старые ответы из `/var/lib/hotg-playtest/responses.jsonl` в SQLite один раз. Исходный JSONL остаётся как резервная копия. Статистика и выгрузка на сервере:

```bash
sudo -u playtest-survey python3 -I /opt/playtest-survey/storage.py stats
umask 077
sudo -u playtest-survey python3 -I /opt/playtest-survey/storage.py export > /root/hotg-playtest-answers.jsonl
```

Сервис Node.js слушает только `127.0.0.1:8127`; внешний доступ идёт через HTTPS Nginx.

## Публикация

Сайт: `https://turrium.ru/playtest/`; анкета: `https://turrium.ru/playtest/feedback/`. Статические файлы лежат в `/var/www/turrium.ru/playtest/`, установщик — в `downloads/`, `server.js` и `storage.py` — в `/opt/playtest-survey/`. `hotg.turrium.ru` пока не делегирован в DNS.

Пока основной сайт закрыт, `location /` в `/etc/nginx/sites-available/turrium.ru` отдаёт временный редирект 302 на `https://turrium.ru/playtest/`. Маршруты `/playtest/` и `/api/max/webhook` имеют отдельные правила и продолжают работать. Резервная копия прежней конфигурации — `/etc/nginx/sites-available/turrium.ru.bak-hotg-redirect-20260925`.
