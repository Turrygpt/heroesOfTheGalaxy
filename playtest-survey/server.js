"use strict";

const http = require("node:http");
const crypto = require("node:crypto");
const path = require("node:path");
const { spawn } = require("node:child_process");

const HOST = process.env.HOTG_PLAYTEST_HOST || "127.0.0.1";
const PORT = Number(process.env.HOTG_PLAYTEST_PORT || 8127);
const PYTHON = process.env.HOTG_PLAYTEST_PYTHON || "python3";
const MAX_BODY_BYTES = 24_000;
const COOKIE_NAME = "hotg_playtest_sid";
const COOKIE_AGE = 60 * 60 * 24 * 30;
const ADMIN_COOKIE_NAME = "hotg_playtest_admin";
const ADMIN_COOKIE_AGE = 60 * 60 * 12;
const ADMIN_PASSWORD_HASH = process.env.HOTG_ADMIN_PASSWORD_HASH || "";
const DEMO_VERSION = process.env.HOTG_DEMO_VERSION || "0.12.0";
const DEMO_INSTALLER = `HeroesOfTheGalaxyDemo-${DEMO_VERSION}-windows-x64-setup.exe`;
const ALLOWED_ORIGINS = new Set(
  (process.env.HOTG_PLAYTEST_ORIGINS || "https://turrium.ru,https://www.turrium.ru").split(",")
);
const adminSessions = new Map();
const failedLogins = new Map();
let recentFailedLogins = [];

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

function cookieToken(request, name) {
  const cookies = String(request.headers.cookie || "").split(";");
  const cookie = cookies.map((item) => item.trim()).find((item) => item.startsWith(`${name}=`));
  const token = cookie?.slice(name.length + 1);
  return token && /^[A-Za-z0-9_-]{43}$/.test(token) ? token : null;
}

function sessionToken(request) {
  return cookieToken(request, COOKIE_NAME);
}

function sessionHash(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function storage(action, data) {
  return new Promise((resolve, reject) => {
    const child = spawn(PYTHON, ["-I", path.join(__dirname, "storage.py"), action], {
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

function sameOrigin(request) {
  return ALLOWED_ORIGINS.has(String(request.headers.origin || ""));
}

async function readJson(request, response) {
  if (!request.headers["content-type"]?.startsWith("application/json")) {
    reply(response, 415, { message: "unsupported_media_type" });
    return null;
  }
  if (Number(request.headers["content-length"] || 0) > MAX_BODY_BYTES) {
    reply(response, 413, { message: "payload_too_large" });
    return null;
  }
  const chunks = [];
  let size = 0;
  try {
    for await (const chunk of request) {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reply(response, 413, { message: "payload_too_large" });
        return null;
      }
      chunks.push(chunk);
    }
    return { value: JSON.parse(Buffer.concat(chunks).toString("utf8")) };
  } catch {
    reply(response, 400, { message: "invalid_request" });
    return null;
  }
}

function cleanReview(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  if (typeof raw.website === "string" && raw.website.trim()) return { spam: true };
  if (typeof raw.body !== "string") return null;
  const body = raw.body.trim();
  const author = typeof raw.author === "string" ? raw.author.trim() : "";
  const rating = raw.rating === "" || raw.rating == null ? null : Number(raw.rating);
  if (body.length < 5 || body.length > 2000 || author.length > 40) return null;
  if (rating !== null && (!Number.isInteger(rating) || rating < 1 || rating > 5)) return null;
  return { author: author || "Игрок", body, rating };
}

function verifyAdminPassword(password) {
  const parts = ADMIN_PASSWORD_HASH.split(":");
  if (parts.length !== 2 || !/^[0-9a-f]{32}$/.test(parts[0]) || !/^[0-9a-f]{128}$/.test(parts[1])) return false;
  const expected = Buffer.from(parts[1], "hex");
  const actual = crypto.scryptSync(password, Buffer.from(parts[0], "hex"), expected.length);
  return crypto.timingSafeEqual(actual, expected);
}

function loginAddress(request) {
  return String(request.headers["x-real-ip"] || request.socket.remoteAddress || "unknown");
}

function loginLocked(request) {
  const cutoff = Date.now() - 15 * 60 * 1000;
  const address = loginAddress(request);
  const local = (failedLogins.get(address) || []).filter((time) => time > cutoff);
  failedLogins.set(address, local);
  recentFailedLogins = recentFailedLogins.filter((time) => time > cutoff);
  return local.length >= 5 || recentFailedLogins.length >= 20;
}

function recordFailedLogin(request) {
  const address = loginAddress(request);
  failedLogins.set(address, [...(failedLogins.get(address) || []), Date.now()]);
  recentFailedLogins.push(Date.now());
}

function adminSession(request) {
  const token = cookieToken(request, ADMIN_COOKIE_NAME);
  if (!token) return null;
  const key = sessionHash(token);
  const expires = adminSessions.get(key);
  if (!expires) return null;
  if (expires <= Date.now()) {
    adminSessions.delete(key);
    return null;
  }
  return key;
}

async function handleReviewRoute(request, response) {
  const url = request.url || "";
  if (url === "/download" && ["GET", "HEAD"].includes(request.method)) {
    if (request.method === "GET") {
      try {
        await storage("download_hit", { version: DEMO_VERSION });
      } catch {
        console.error("Не удалось увеличить счётчик скачиваний");
      }
    }
    response.writeHead(302, {
      Location: `/playtest/downloads/${DEMO_INSTALLER}`,
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    });
    response.end();
    return true;
  }
  if (url === "/reviews" && request.method === "GET") {
    reply(response, 200, await storage("review_public", {}));
    return true;
  }
  if (url === "/reviews" && request.method === "POST") {
    if (!sameOrigin(request)) { reply(response, 403, { message: "forbidden" }); return true; }
    const token = sessionToken(request);
    if (!token) { reply(response, 401, { message: "session_required" }); return true; }
    const parsed = await readJson(request, response);
    if (!parsed) return true;
    const review = cleanReview(parsed.value);
    if (!review) { reply(response, 400, { message: "invalid_review" }); return true; }
    if (review.spam) { reply(response, 201, { message: "pending" }); return true; }
    const result = await storage("review_submit", { session_hash: sessionHash(token), ...review });
    if (result.status === "already_used") reply(response, 409, { message: "already_submitted" });
    else if (result.status === "session_required") reply(response, 401, { message: "session_required" });
    else if (result.status === "pending") reply(response, 201, { message: "pending" });
    else reply(response, 500, { message: "save_failed" });
    return true;
  }
  if (url === "/admin/session" && request.method === "GET") {
    reply(response, 200, { authenticated: Boolean(adminSession(request)) });
    return true;
  }
  if (url === "/admin/login" && request.method === "POST") {
    if (!sameOrigin(request)) { reply(response, 403, { message: "forbidden" }); return true; }
    if (!ADMIN_PASSWORD_HASH) { reply(response, 503, { message: "admin_unavailable" }); return true; }
    if (loginLocked(request)) { reply(response, 429, { message: "too_many_attempts" }); return true; }
    const parsed = await readJson(request, response);
    if (!parsed) return true;
    const username = parsed.value?.username;
    const password = parsed.value?.password;
    if (typeof username !== "string" || typeof password !== "string" || password.length > 128) {
      reply(response, 400, { message: "invalid_request" });
      return true;
    }
    const validPassword = verifyAdminPassword(password);
    if (username !== "admin" || !validPassword) {
      recordFailedLogin(request);
      reply(response, 401, { message: "invalid_credentials" });
      return true;
    }
    failedLogins.delete(loginAddress(request));
    const token = crypto.randomBytes(32).toString("base64url");
    adminSessions.set(sessionHash(token), Date.now() + ADMIN_COOKIE_AGE * 1000);
    reply(response, 200, { authenticated: true }, {
      "Set-Cookie": `${ADMIN_COOKIE_NAME}=${token}; Max-Age=${ADMIN_COOKIE_AGE}; Path=/playtest/api/admin; Secure; HttpOnly; SameSite=Strict`,
    });
    return true;
  }
  if (url === "/admin/logout" && request.method === "POST") {
    if (!sameOrigin(request)) { reply(response, 403, { message: "forbidden" }); return true; }
    const key = adminSession(request);
    if (key) adminSessions.delete(key);
    reply(response, 200, { authenticated: false }, {
      "Set-Cookie": `${ADMIN_COOKIE_NAME}=; Max-Age=0; Path=/playtest/api/admin; Secure; HttpOnly; SameSite=Strict`,
    });
    return true;
  }
  if (url === "/admin/reviews" && request.method === "GET") {
    if (!adminSession(request)) { reply(response, 401, { message: "login_required" }); return true; }
    reply(response, 200, await storage("review_list", {}));
    return true;
  }
  if (url === "/admin/stats" && request.method === "GET") {
    if (!adminSession(request)) { reply(response, 401, { message: "login_required" }); return true; }
    reply(response, 200, await storage("download_stats", {}));
    return true;
  }
  const statusMatch = /^\/admin\/reviews\/([1-9][0-9]*)\/status$/.exec(url);
  if (statusMatch && request.method === "POST") {
    if (!sameOrigin(request)) { reply(response, 403, { message: "forbidden" }); return true; }
    if (!adminSession(request)) { reply(response, 401, { message: "login_required" }); return true; }
    const parsed = await readJson(request, response);
    if (!parsed) return true;
    const status = parsed.value?.status;
    if (!["pending", "published", "rejected"].includes(status)) {
      reply(response, 400, { message: "invalid_status" });
      return true;
    }
    const result = await storage("review_status", { id: Number(statusMatch[1]), status });
    reply(response, result.status === "updated" ? 200 : 404, { message: result.status });
    return true;
  }
  return false;
}

const server = http.createServer(async (request, response) => {
  try {
    if (await handleReviewRoute(request, response)) return;
  } catch {
    reply(response, 500, { message: "service_failed" });
    return;
  }
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
