"use strict";

const ADMIN_API = "/playtest/api/admin";
const loginPanel = document.getElementById("admin-auth");
const dashboard = document.getElementById("admin-dashboard");
const loginForm = document.getElementById("admin-login-form");
const loginButton = document.getElementById("admin-login-button");
const loginStatus = document.getElementById("admin-login-status");
const actionStatus = document.getElementById("admin-action-status");
const reviewList = document.getElementById("admin-review-list");
const reviewCount = document.getElementById("admin-review-count");
const statusFilter = document.getElementById("admin-status-filter");
const downloadTotal = document.getElementById("admin-download-total");
const downloadVersions = document.getElementById("admin-download-versions");
const surveyList = document.getElementById("admin-survey-list");
const surveyCount = document.getElementById("admin-survey-count");
const surveyTotal = document.getElementById("admin-survey-total");
const surveyStatus = document.getElementById("admin-survey-status");
const reviewsTab = document.getElementById("admin-reviews-tab");
const surveysTab = document.getElementById("admin-surveys-tab");
const reviewsPanel = document.getElementById("admin-reviews-panel");
const surveysPanel = document.getElementById("admin-surveys-panel");
let reviews = [];
let surveys = [];

const surveySections = [
  {
    title: "Ваш игровой заход",
    fields: [
      ["play_time", "Сколько времени вы провели в игре?"],
      ["progress", "До какого момента вы дошли?"],
      ["demo_version", "Версия игры"],
      ["sessions", "Сколько отдельных игровых сессий у вас было?"],
      ["stop_reason", "Если вы остановились до финала, что повлияло на это?"],
      ["strategy_experience", "Насколько вам знакомы пошаговые стратегии?"],
    ],
  },
  {
    title: "Первые впечатления",
    fields: [
      ["clarity_map", "Глобальная карта: куда двигаться и что можно посетить"],
      ["clarity_economy", "Ресурсы, постройки и найм флота"],
      ["clarity_battle", "Тактические бои: правила, ходы и управление"],
      ["clarity_mission", "Цели миссии, журнал заданий и радиопереговоры"],
      ["difficulty", "Как вам общая сложность миссии?"],
      ["friction", "Где вы чаще всего теряли время или не понимали, что делать дальше?"],
    ],
  },
  {
    title: "Карта, экономика и решения",
    fields: [
      ["clarity_route", "Построить маршрут и понять, что мешает пройти дальше"],
      ["clarity_map_info", "По значкам и подсказкам понять, что находится на карте и где опасно"],
      ["clarity_turn_cycle", "Понять, что меняется после завершения дня и недели"],
      ["clarity_buildings", "Понять, что строить или нанимать, сколько это стоит и что откроет"],
      ["clarity_rewards", "Понять, что дают станции, нейтральные объекты и найденные награды"],
      ["clarity_enemy_threat", "Оценить угрозу от патрулей, пиратов и других флотов до столкновения"],
      ["strategic_choice", "Насколько значимыми казались решения о маршруте и развитии?"],
      ["resource_blocker", "Что чаще всего мешало выполнить задуманное?"],
      ["route_taken", "Как вы прошли или планировали пройти центральный рубеж?"],
      ["strategic_stuck", "В какой момент на карте вы в последний раз не понимали, что делать дальше?"],
      ["resource_example", "Если ресурсы останавливали ваш план, приведите конкретный пример"],
    ],
  },
  {
    title: "Тактические бои",
    fields: [
      ["combat_clarity_turn_order", "Понимать, чей ход и кто будет действовать следующим"],
      ["combat_clarity_move", "Понимать, куда отряд может переместиться и где встанет корабль"],
      ["combat_clarity_range", "Понимать, до кого можно достать и как расстояние влияет на урон"],
      ["combat_clarity_preview", "Предсказать результат атаки по стрелке, подсказке и показу урона"],
      ["combat_clarity_abilities", "Понять способности кораблей, протоколы и их цели"],
      ["combat_clarity_losses", "Понять, сколько кораблей потеряно и почему"],
      ["combat_clarity_result", "Понять итог боя и последствия для флота после возвращения на карту"],
      ["combat_difficulty", "Как ощущалась сложность боёв?"],
      ["combat_losses", "Как ваши потери обычно соотносились с тем, чего вы ожидали?"],
      ["combat_features", "Какими возможностями вы пользовались?"],
      ["battle_example", "Опишите бой, в котором пришлось менять план или который запомнился"],
      ["battle_problem", "Что в бою вы бы исправили в первую очередь?"],
    ],
  },
  {
    title: "Сюжет, впечатления и предложения",
    fields: [
      ["story_clarity", "Насколько вам были понятны мотивы сторон и происходящее в сюжете?"],
      ["mission_journal", "Насколько полезными были журнал миссии и история радиопереговоров?"],
      ["optional_interest", "Насколько хотелось разбираться в необязательных контрактах и встречах?"],
      ["text_readability", "Насколько комфортно читались тексты интерфейса и диалогов?"],
      ["technical_issues", "Как игра работала на вашем компьютере?"],
      ["platform", "На какой системе запускали игру? Это поможет воспроизвести технические проблемы."],
      ["overall_fun", "Насколько вам в целом понравилась игра?"],
      ["recommend", "Какова вероятность, что вы посоветуете попробовать игру другу?"],
      ["favorite", "Какой момент, корабль или система запомнились больше всего?"],
      ["confusing", "Где было непонятно, скучно или слишком трудно?"],
      ["bug", "Встретили ошибку или техническую проблему?"],
      ["add_change", "Чего не хватило? Что добавить, убрать или переделать?"],
      ["top_priority", "Если исправить только одну вещь — что важнее всего?"],
      ["preserve", "Что в игре точно стоит сохранить и не потерять при изменениях?"],
      ["continue_reason", "Что должно появиться или измениться, чтобы вам захотелось сыграть ещё раз?"],
    ],
  },
];
const surveyLabels = new Map(surveySections.flatMap((section) => section.fields));

function showLogin() {
  loginPanel.hidden = false;
  dashboard.hidden = true;
  reviews = [];
  surveys = [];
  reviewList.replaceChildren();
  surveyList.replaceChildren();
  surveyCount.textContent = "—";
  surveyTotal.textContent = "";
}

function showDashboard() {
  loginPanel.hidden = true;
  dashboard.hidden = false;
  loginForm.reset();
  loginForm.elements.username.value = "admin";
  loginStatus.textContent = "";
  loadReviews();
  loadSurveys();
  loadStats();
}

function formatDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("ru-RU", {
    day: "numeric", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit",
  }).format(date);
}

function actionButton(label, status, id) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = status === "published" ? "admin-action primary" : "admin-action";
  button.textContent = label;
  button.addEventListener("click", async () => {
    button.disabled = true;
    actionStatus.textContent = "";
    try {
      const response = await fetch(`${ADMIN_API}/reviews/${id}/status`, {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status }),
      });
      if (response.status === 401) { showLogin(); return; }
      if (!response.ok) throw new Error("update_failed");
      actionStatus.classList.add("is-success");
      actionStatus.textContent = "Статус отзыва изменён.";
      await loadReviews();
    } catch {
      actionStatus.classList.remove("is-success");
      actionStatus.textContent = "Не удалось изменить статус. Попробуйте снова.";
      button.disabled = false;
    }
  });
  return button;
}

function reviewCard(review) {
  const card = document.createElement("article");
  card.className = "admin-review-card";

  const heading = document.createElement("div");
  heading.className = "admin-review-heading";
  const author = document.createElement("strong");
  author.textContent = review.author;
  heading.append(author);
  if (review.rating) {
    const rating = document.createElement("span");
    rating.className = "review-stars";
    rating.textContent = "★".repeat(review.rating) + "☆".repeat(5 - review.rating);
    heading.append(rating);
  }
  const date = document.createElement("time");
  date.textContent = formatDate(review.created_at);
  heading.append(date);
  card.append(heading);

  const body = document.createElement("p");
  body.textContent = review.body;
  card.append(body);

  const actions = document.createElement("div");
  actions.className = "admin-review-actions";
  if (review.status === "pending") {
    actions.append(actionButton("Опубликовать", "published", review.id));
    actions.append(actionButton("Отклонить", "rejected", review.id));
  } else if (review.status === "published") {
    actions.append(actionButton("Скрыть с сайта", "pending", review.id));
  } else {
    actions.append(actionButton("Вернуть на проверку", "pending", review.id));
  }
  card.append(actions);
  return card;
}

function renderReviews() {
  const filter = statusFilter.value;
  const visible = filter === "all" ? reviews : reviews.filter((review) => review.status === filter);
  reviewList.replaceChildren();
  reviewCount.textContent = `${visible.length} из ${reviews.length}`;
  if (visible.length === 0) {
    const empty = document.createElement("p");
    empty.className = "review-empty";
    empty.textContent = "Здесь пока нет отзывов.";
    reviewList.append(empty);
    return;
  }
  for (const review of visible) reviewList.append(reviewCard(review));
}

function answerText(value) {
  if (Array.isArray(value)) return value.map(String).join(" · ") || "—";
  if (value && typeof value === "object") return JSON.stringify(value);
  return String(value);
}

function surveyAnswerRow(key, value) {
  const row = document.createElement("div");
  row.className = "admin-survey-answer";
  const question = document.createElement("dt");
  question.textContent = surveyLabels.get(key) || key.replaceAll("_", " ");
  const answer = document.createElement("dd");
  answer.textContent = answerText(value);
  row.append(question, answer);
  return row;
}

function surveyCard(survey) {
  const answers = survey.answers && typeof survey.answers === "object" && !Array.isArray(survey.answers)
    ? survey.answers
    : {};
  const card = document.createElement("details");
  card.className = "admin-survey-card";

  const summary = document.createElement("summary");
  const title = document.createElement("strong");
  title.textContent = `Анкета №${survey.id}`;
  summary.append(title);
  if (answers.play_time) {
    const playTime = document.createElement("span");
    playTime.className = "admin-survey-tag";
    playTime.textContent = answers.play_time;
    summary.append(playTime);
  }
  if (answers.overall_fun) {
    const rating = document.createElement("span");
    rating.className = "admin-survey-tag admin-survey-rating";
    rating.textContent = `Оценка ${answerText(answers.overall_fun)} из 5`;
    summary.append(rating);
  }
  card.append(summary);

  const response = document.createElement("div");
  response.className = "admin-survey-response";
  const knownKeys = new Set();
  for (const section of surveySections) {
    const answered = section.fields.filter(([key]) => {
      knownKeys.add(key);
      const value = answers[key];
      return value !== undefined && value !== null && value !== "" && !(Array.isArray(value) && value.length === 0);
    });
    if (answered.length === 0) continue;
    const group = document.createElement("section");
    group.className = "admin-survey-section";
    const heading = document.createElement("h3");
    heading.textContent = section.title;
    const list = document.createElement("dl");
    list.className = "admin-survey-answers";
    for (const [key] of answered) list.append(surveyAnswerRow(key, answers[key]));
    group.append(heading, list);
    response.append(group);
  }

  const extraKeys = Object.keys(answers).filter((key) => !knownKeys.has(key) && key !== "website");
  if (extraKeys.length > 0) {
    const group = document.createElement("section");
    group.className = "admin-survey-section";
    const heading = document.createElement("h3");
    heading.textContent = "Другие ответы";
    const list = document.createElement("dl");
    list.className = "admin-survey-answers";
    for (const key of extraKeys) list.append(surveyAnswerRow(key, answers[key]));
    group.append(heading, list);
    response.append(group);
  }
  card.append(response);
  return card;
}

function renderSurveys() {
  surveyList.replaceChildren();
  surveyCount.textContent = Number(surveyTotal.dataset.count || 0).toLocaleString("ru-RU");
  const total = Number(surveyTotal.dataset.count || 0);
  surveyTotal.textContent = surveys.length < total
    ? `Показаны ${surveys.length} последних из ${total}`
    : `Всего анкет: ${total}`;
  if (surveys.length === 0) {
    const empty = document.createElement("p");
    empty.className = "review-empty";
    empty.textContent = "Пока нет отправленных анкет.";
    surveyList.append(empty);
    return;
  }
  for (const survey of surveys) surveyList.append(surveyCard(survey));
}

async function loadReviews() {
  try {
    const response = await fetch(`${ADMIN_API}/reviews`, { credentials: "same-origin" });
    if (response.status === 401) { showLogin(); return; }
    if (!response.ok) throw new Error("load_failed");
    const data = await response.json();
    reviews = Array.isArray(data.reviews) ? data.reviews : [];
    renderReviews();
  } catch {
    actionStatus.classList.remove("is-success");
    actionStatus.textContent = "Не удалось загрузить отзывы. Попробуйте обновить список.";
  }
}

async function loadSurveys() {
  surveyStatus.classList.remove("is-success");
  surveyStatus.textContent = "Загружаем анкеты…";
  try {
    const response = await fetch(`${ADMIN_API}/surveys`, { credentials: "same-origin" });
    if (response.status === 401) { showLogin(); return; }
    if (!response.ok) throw new Error("load_failed");
    const data = await response.json();
    surveys = Array.isArray(data.surveys) ? data.surveys : [];
    surveyTotal.dataset.count = String(Number(data.total || 0));
    surveyStatus.textContent = "";
    renderSurveys();
  } catch {
    surveyStatus.textContent = "Не удалось загрузить анкеты. Попробуйте обновить список.";
  }
}

async function loadStats() {
  try {
    const response = await fetch(`${ADMIN_API}/stats`, { credentials: "same-origin" });
    if (response.status === 401) { showLogin(); return; }
    if (!response.ok) throw new Error("load_failed");
    const data = await response.json();
    downloadTotal.textContent = Number(data.total || 0).toLocaleString("ru-RU");
    downloadVersions.replaceChildren();
    if (!Array.isArray(data.versions) || data.versions.length === 0) {
      downloadVersions.textContent = "Пока нет скачиваний";
      return;
    }
    for (const item of data.versions) {
      const row = document.createElement("div");
      row.className = "admin-version-row";
      const version = document.createElement("span");
      version.textContent = item.version;
      const count = document.createElement("strong");
      count.textContent = Number(item.count || 0).toLocaleString("ru-RU");
      row.append(version, count);
      downloadVersions.append(row);
    }
  } catch {
    downloadTotal.textContent = "—";
    downloadVersions.textContent = "Не удалось загрузить статистику";
  }
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  loginStatus.textContent = "";
  loginButton.disabled = true;
  try {
    const response = await fetch(`${ADMIN_API}/login`, {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username: loginForm.elements.username.value,
        password: loginForm.elements.password.value,
      }),
    });
    if (response.status === 429) {
      loginStatus.textContent = "Слишком много попыток. Повторите через 15 минут.";
    } else if (response.status === 401) {
      loginStatus.textContent = "Неверный логин или пароль.";
    } else if (response.status === 503) {
      loginStatus.textContent = "Вход пока не настроен на сервере.";
    } else if (!response.ok) {
      throw new Error("login_failed");
    } else {
      showDashboard();
    }
  } catch {
    loginStatus.textContent = "Не удалось войти. Попробуйте позже.";
  } finally {
    loginButton.disabled = false;
  }
});

document.getElementById("admin-refresh").addEventListener("click", () => {
  loadReviews();
  loadSurveys();
  loadStats();
});
document.getElementById("admin-logout").addEventListener("click", async () => {
  try {
    await fetch(`${ADMIN_API}/logout`, { method: "POST", credentials: "same-origin" });
  } finally {
    showLogin();
  }
});
statusFilter.addEventListener("change", renderReviews);

function selectAdminTab(selectedTab) {
  const showSurveys = selectedTab === surveysTab;
  reviewsTab.setAttribute("aria-selected", String(!showSurveys));
  reviewsTab.tabIndex = showSurveys ? -1 : 0;
  surveysTab.setAttribute("aria-selected", String(showSurveys));
  surveysTab.tabIndex = showSurveys ? 0 : -1;
  reviewsPanel.hidden = showSurveys;
  surveysPanel.hidden = !showSurveys;
}

reviewsTab.addEventListener("click", () => selectAdminTab(reviewsTab));
surveysTab.addEventListener("click", () => selectAdminTab(surveysTab));
for (const tab of [reviewsTab, surveysTab]) {
  tab.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    const nextTab = tab === reviewsTab ? surveysTab : reviewsTab;
    selectAdminTab(nextTab);
    nextTab.focus();
  });
}

fetch(`${ADMIN_API}/session`, { credentials: "same-origin" })
  .then((response) => response.ok ? response.json() : { authenticated: false })
  .then((data) => data.authenticated ? showDashboard() : showLogin())
  .catch(showLogin);
