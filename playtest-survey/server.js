"use strict";

const http = require("node:http");
const crypto = require("node:crypto");
const path = require("node:path");
const { spawn } = require("node:child_process");

const HOST = "127.0.0.1";
const PORT = 8127;
const MAX_BODY_BYTES = 24_000;
const COOKIE_NAME = "hotg_playtest_sid";
const COOKIE_AGE = 60 * 60 * 24 * 30;

const allowed = {
  play_time: ["До 30 минут", "30–60 минут", "1–3 часа", "4–8 часов", "Больше 8 часов"],
  progress: ["Только начал", "Первые задания", "Середина миссии", "Финал миссии", "Завершил миссию", "Пробовал несколько заходов"],
  sessions: ["1", "2–3", "4 и больше"],
  stop_reason: ["Планировал продолжить позже", "Не понял следующую цель", "Стало слишком трудно", "Стало однообразно или скучно", "Техническая проблема", "Не хватило времени", "Другое"],
  strategy_experience: ["Почти не играл", "Иногда играю", "Играю часто"],
  clarity_map: ["1", "2", "3", "4", "5", "Не дошёл"],
  clarity_economy: ["1", "2", "3", "4", "5", "Не дошёл"],
  clarity_battle: ["1", "2", "3", "4", "5", "Не дошёл"],
  clarity_mission: ["1", "2", "3", "4", "5", "Не дошёл"],
  difficulty: ["Слишком легко", "В самый раз", "Сложно, но честно", "Слишком сложно", "Сложность скачет", "Не успел оценить"],
  friction: ["Поиск следующей цели", "Передвижение по карте", "Ресурсы и экономика", "Бои и их правила", "Интерфейс и управление", "Технические проблемы", "Нигде"],
  clarity_route: ["1", "2", "3", "4", "5", "Не видел"],
  clarity_map_info: ["1", "2", "3", "4", "5", "Не видел"],
  clarity_turn_cycle: ["1", "2", "3", "4", "5", "Не видел"],
  clarity_buildings: ["1", "2", "3", "4", "5", "Не видел"],
  clarity_rewards: ["1", "2", "3", "4", "5", "Не видел"],
  clarity_enemy_threat: ["1", "2", "3", "4", "5", "Не видел"],
  strategic_choice: ["Часто выбирал между равноценными вариантами", "Обычно видел один очевидный вариант", "Решения принимал случайно или наугад", "Не успел дойти до таких решений"],
  resource_blocker: ["Кредиты", "Продукты", "Руда", "Научные данные", "Энергокристаллы", "Топливо", "Радиоизотопы", "Не хватало кораблей", "Не хватало очков движения", "Ничего не мешало", "Не дошёл до развития"],
  route_taken: ["Пошёл через патруль с боем", "Искал дипломатический проход", "Искал южный обход", "Не понял, что есть альтернативы", "Не дошёл до рубежа", "Не помню"],
  combat_clarity_turn_order: ["1", "2", "3", "4", "5", "Не видел"],
  combat_clarity_move: ["1", "2", "3", "4", "5", "Не видел"],
  combat_clarity_range: ["1", "2", "3", "4", "5", "Не видел"],
  combat_clarity_preview: ["1", "2", "3", "4", "5", "Не видел"],
  combat_clarity_abilities: ["1", "2", "3", "4", "5", "Не видел"],
  combat_clarity_losses: ["1", "2", "3", "4", "5", "Не видел"],
  combat_clarity_result: ["1", "2", "3", "4", "5", "Не видел"],
  combat_difficulty: ["Слишком легко", "В самый раз", "Сложно, но честно", "Слишком сложно", "Сильно менялась от боя к бою", "Не успел оценить"],
  combat_losses: ["Меньше, чем ожидал", "Примерно как ожидал", "Больше, чем ожидал", "Не понимал, почему теряю корабли", "Не было заметных потерь", "Не успел оценить"],
  combat_features: ["Подсказка характеристик отряда", "Предпросмотр урона при наведении", "Особые способности кораблей", "Протоколы командира", "Автобитва", "Отступление", "Предварительный прогноз силы боя", "Не заметил эти возможности"],
  overall_fun: ["1", "2", "3", "4", "5"],
  recommend: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
  story_clarity: ["1", "2", "3", "4", "5", "Не дошёл"],
  mission_journal: ["1", "2", "3", "4", "5", "Не открывал"],
  optional_interest: ["1", "2", "3", "4", "5", "Не видел"],
  text_readability: ["1", "2", "3", "4", "5", "Не помню"],
  technical_issues: ["Работала стабильно", "Были мелкие помехи", "Проблемы мешали играть", "Не смог нормально запустить"],
  platform: ["Windows 10", "Windows 11", "Linux / совместимый слой", "Другая система", "Не знаю"],
};

const arrayFields = new Set(["friction", "stop_reason", "resource_blocker", "combat_features"]);

const textLimits = {
  favorite: 1200,
  confusing: 1600,
  bug: 1800,
  add_change: 1800,
  top_priority: 1000,
  strategic_stuck: 1200,
  resource_example: 1200,
  battle_example: 1400,
  battle_problem: 1400,
  preserve: 1000,
  continue_reason: 1200,
};

function reply(response, statusCode, message, headers = {}) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    ...headers,
  });
  response.end(JSON.stringify(message));
}

function sessionToken(request) {
  const cookies = String(request.headers.cookie || "").split(";");
  const cookie = cookies.map((item) => item.trim()).find((item) => item.startsWith(`${COOKIE_NAME}=`));
  const token = cookie?.slice(COOKIE_NAME.length + 1);
  return token && /^[A-Za-z0-9_-]{43}$/.test(token) ? token : null;
}

function sessionHash(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function storage(action, data) {
  return new Promise((resolve, reject) => {
    const child = spawn("python3", ["-I", path.join(__dirname, "storage.py"), action], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    let output = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) return reject(new Error("storage_failed"));
      try { resolve(JSON.parse(output)); } catch { reject(new Error("storage_failed")); }
    });
    child.stdin.end(JSON.stringify(data));
  });
}

function cleanAnswers(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const result = {};
  if (typeof raw.website === "string" && raw.website.trim()) return { spam: true };

  for (const [key, options] of Object.entries(allowed)) {
    if (!(key in raw)) continue;
    if (arrayFields.has(key)) {
      if (!Array.isArray(raw[key]) || raw[key].length > options.length || raw[key].some((value) => !options.includes(value))) return null;
      result[key] = [...new Set(raw[key])];
      continue;
    }
    if (typeof raw[key] !== "string" || !options.includes(raw[key])) return null;
    result[key] = raw[key];
  }

  for (const [key, maxLength] of Object.entries(textLimits)) {
    if (!(key in raw)) continue;
    if (typeof raw[key] !== "string" || raw[key].length > maxLength) return null;
    const value = raw[key].trim();
    if (value) result[key] = value;
  }

  if (!result.play_time || !result.overall_fun) return null;
  return { answers: result };
}

const server = http.createServer(async (request, response) => {
  if (request.method === "GET" && request.url === "/session") {
    const token = sessionToken(request) || crypto.randomBytes(32).toString("base64url");
    try {
      const result = await storage("session", { session_hash: sessionHash(token) });
      reply(response, 200, { submitted: result.submitted }, {
        "Set-Cookie": `${COOKIE_NAME}=${token}; Max-Age=${COOKIE_AGE}; Path=/playtest/api; Secure; HttpOnly; SameSite=Lax`,
      });
    } catch {
      reply(response, 500, { message: "session_failed" });
    }
    return;
  }
  if (request.method !== "POST" || request.url !== "/submit") {
    reply(response, 404, { message: "not_found" });
    return;
  }
  const token = sessionToken(request);
  if (!token) {
    reply(response, 401, { message: "session_required" });
    return;
  }
  if (!request.headers["content-type"]?.startsWith("application/json")) {
    reply(response, 415, { message: "unsupported_media_type" });
    return;
  }
  const declaredLength = Number(request.headers["content-length"] || 0);
  if (declaredLength > MAX_BODY_BYTES) {
    reply(response, 413, { message: "payload_too_large" });
    return;
  }

  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) {
      reply(response, 413, { message: "payload_too_large" });
      return;
    }
    chunks.push(chunk);
  }

  let body;
  try {
    body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    reply(response, 400, { message: "invalid_request" });
    return;
  }

  const cleaned = cleanAnswers(body?.answers);
  if (!cleaned) {
    reply(response, 400, { message: "invalid_answers" });
    return;
  }
  if (cleaned.spam) {
    reply(response, 201, { message: "accepted" });
    return;
  }

  try {
    const result = await storage("submit", { session_hash: sessionHash(token), answers: cleaned.answers });
    if (result.status === "already_used") {
      reply(response, 409, { message: "already_submitted" });
      return;
    }
    if (result.status === "session_required") {
      reply(response, 401, { message: "session_required" });
      return;
    }
    if (result.status !== "accepted") throw new Error("save_failed");
  } catch {
    reply(response, 500, { message: "save_failed" });
    return;
  }
  reply(response, 201, { message: "accepted" });
});

server.listen(PORT, HOST);
