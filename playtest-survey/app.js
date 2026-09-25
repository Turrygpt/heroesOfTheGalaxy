"use strict";

const form = document.querySelector("#survey-form");
const status = document.querySelector("#form-status");
const submitButton = document.querySelector("#submit-button");
const progressFill = document.querySelector("#progress-fill");
const progressLabel = document.querySelector("#progress-label");
const progressCount = document.querySelector("#progress-count");
const successPanel = document.querySelector("#success-panel");
let sessionReady = false;
submitButton.disabled = true;
status.textContent = "Открываем анонимную сессию…";
const stepNames = ["Ваш игровой опыт", "Первое знакомство", "Карта и экономика", "Тактические бои", "Сюжет и приоритеты"];

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[character]);
}

const detailedSections = [
  {
    step: 3,
    eyebrow: "СТРАТЕГИЧЕСКАЯ КАРТА",
    title: "Маршрут, экономика и решения",
    hint: "Отвечайте только про то, с чем успели столкнуться. Это помогает понять, где интерфейс или правила не объясняют последствия.",
    fields: [
      { type: "rating", name: "clarity_route", label: "Построить маршрут и понять, что мешает пройти дальше", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "clarity_map_info", label: "По значкам и подсказкам понять, что находится на карте и где опасно", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "clarity_turn_cycle", label: "Понять, что меняется после завершения дня и недели", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "clarity_buildings", label: "Понять, что строить или нанимать, сколько это стоит и что откроет", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "clarity_rewards", label: "Понять, что дают станции, нейтральные объекты и найденные награды", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "clarity_enemy_threat", label: "Оценить угрозу от патрулей, пиратов и других флотов до столкновения", low: "Неясно", high: "Понятно" },
      { type: "choice", name: "strategic_choice", label: "Насколько значимыми казались решения о маршруте и развитии?", options: ["Часто выбирал между равноценными вариантами", "Обычно видел один очевидный вариант", "Решения принимал случайно или наугад", "Не успел дойти до таких решений"] },
      { type: "check", name: "resource_blocker", label: "Что чаще всего мешало выполнить задуманное?", options: ["Кредиты", "Продукты", "Руда", "Научные данные", "Энергокристаллы", "Топливо", "Радиоизотопы", "Не хватало кораблей", "Не хватало очков движения", "Ничего не мешало", "Не дошёл до развития"] },
      { type: "choice", name: "route_taken", label: "Как вы прошли или планировали пройти центральный рубеж?", options: ["Пошёл через патруль с боем", "Искал дипломатический проход", "Искал южный обход", "Не понял, что есть альтернативы", "Не дошёл до рубежа", "Не помню"] },
      { type: "text", name: "strategic_stuck", label: "В какой момент на карте вы в последний раз не понимали, что делать дальше?", placeholder: "Укажите место, задачу или действие, которое пытались найти.", max: 1200 },
      { type: "text", name: "resource_example", label: "Если ресурсы останавливали ваш план, приведите конкретный пример", placeholder: "Чего не хватало, что хотели сделать и как решили проблему (если решили)?", max: 1200 },
    ],
  },
  {
    step: 4,
    eyebrow: "ТАКТИЧЕСКИЕ БОИ",
    title: "Понятность, выбор и потери",
    hint: "«Не видел» — нормальный ответ. Оцените, насколько игра показывала нужную информацию, а не насколько хорошо вы запомнили правила.",
    fields: [
      { type: "rating", name: "combat_clarity_turn_order", label: "Понимать, чей ход и кто будет действовать следующим", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "combat_clarity_move", label: "Понимать, куда отряд может переместиться и где встанет корабль", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "combat_clarity_range", label: "Понимать, до кого можно достать и как расстояние влияет на урон", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "combat_clarity_preview", label: "Предсказать результат атаки по стрелке, подсказке и показу урона", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "combat_clarity_abilities", label: "Понять способности кораблей, протоколы и их цели", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "combat_clarity_losses", label: "Понять, сколько кораблей потеряно и почему", low: "Неясно", high: "Понятно" },
      { type: "rating", name: "combat_clarity_result", label: "Понять итог боя и последствия для флота после возвращения на карту", low: "Неясно", high: "Понятно" },
      { type: "choice", name: "combat_difficulty", label: "Как ощущалась сложность боёв?", options: ["Слишком легко", "В самый раз", "Сложно, но честно", "Слишком сложно", "Сильно менялась от боя к бою", "Не успел оценить"] },
      { type: "choice", name: "combat_losses", label: "Как ваши потери обычно соотносились с тем, чего вы ожидали?", options: ["Меньше, чем ожидал", "Примерно как ожидал", "Больше, чем ожидал", "Не понимал, почему теряю корабли", "Не было заметных потерь", "Не успел оценить"] },
      { type: "check", name: "combat_features", label: "Какими возможностями вы пользовались?", options: ["Подсказка характеристик отряда", "Предпросмотр урона при наведении", "Особые способности кораблей", "Протоколы командира", "Автобитва", "Отступление", "Предварительный прогноз силы боя", "Не заметил эти возможности"] },
      { type: "text", name: "battle_example", label: "Опишите бой, в котором пришлось менять план или который запомнился", placeholder: "Что произошло, какой выбор вы сделали и был ли понятен результат?", max: 1400 },
      { type: "text", name: "battle_problem", label: "Что в бою вы бы исправили в первую очередь?", placeholder: "Например: непонятный ход, неудобная цель, неожиданная потеря, долгий бой или способность.", max: 1400 },
    ],
  },
];

function renderRating(field) {
  const values = ["1", "2", "3", "4", "5", "Не видел"];
  return `<fieldset class="question rating-question"><legend>${escapeHtml(field.label)}</legend><div class="rating-row" role="radiogroup" aria-label="${escapeHtml(field.label)}">${values.map((value) => `<label class="${value === "Не видел" ? "rating-na" : ""}"><input type="radio" name="${field.name}" value="${value}"><span>${value}</span></label>`).join("")}</div><div class="scale-hint"><span>${escapeHtml(field.low || "Плохо")}</span><span>${escapeHtml(field.high || "Хорошо")}</span></div></fieldset>`;
}

function renderChoice(field) {
  const inputType = field.type === "check" ? "checkbox" : "radio";
  const columns = field.options.length > 4 ? "choice-grid-2" : "choice-grid-2";
  return `<fieldset class="question"><legend>${escapeHtml(field.label)}</legend><div class="choice-grid ${columns}">${field.options.map((option) => `<label class="choice-card"><input type="${inputType}" name="${field.name}" value="${escapeHtml(option)}"><span>${escapeHtml(option)}</span></label>`).join("")}</div></fieldset>`;
}

function renderText(field) {
  return `<div class="question"><label class="field-label" for="${field.name}">${escapeHtml(field.label)}</label><textarea id="${field.name}" name="${field.name}" maxlength="${field.max}" rows="3" placeholder="${escapeHtml(field.placeholder)}"></textarea></div>`;
}

const finalSection = form.querySelector('[data-step="5"]');
finalSection.insertAdjacentHTML("beforebegin", detailedSections.map((section) => {
  const fields = section.fields.map((field) => field.type === "rating" ? renderRating(field) : field.type === "text" ? renderText(field) : renderChoice(field)).join("");
  return `<section class="survey-section panel" data-step="${section.step}" aria-labelledby="step-${section.step}-title"><div class="section-heading"><span class="step-number">0${section.step}</span><div><div class="eyebrow">${escapeHtml(section.eyebrow)}</div><h2 id="step-${section.step}-title">${escapeHtml(section.title)}</h2></div></div><p class="section-hint">${escapeHtml(section.hint)}</p>${fields}</section>`;
}).join(""));

function updateProgress() {
  const totalSteps = stepNames.length;
  const complete = Array.from({ length: totalSteps }, (_, index) => index + 1).map((step) => {
    const section = document.querySelector(`[data-step="${step}"]`);
    return [...section.querySelectorAll("input[type=radio], input[type=checkbox], textarea")]
      .some((input) => input.type === "radio" || input.type === "checkbox" ? input.checked : input.value.trim() !== "");
  });
  const current = complete.findIndex((value) => !value);
  const step = current === -1 ? totalSteps : current + 1;
  progressFill.style.width = `${Math.max(1, complete.filter(Boolean).length) * (100 / totalSteps)}%`;
  progressLabel.textContent = stepNames[step - 1];
  progressCount.textContent = `Этап ${step} из ${totalSteps}`;
}

form.addEventListener("change", updateProgress);
form.addEventListener("input", updateProgress);

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!sessionReady) return;
  status.textContent = "";

  let valid = true;
  for (const group of form.querySelectorAll("[data-required=true]")) {
    const selected = group.querySelector("input:checked");
    const error = group.querySelector(".field-error");
    const missing = !selected;
    error.hidden = !missing;
    valid = valid && !missing;
  }
  if (!valid) {
    form.querySelector("[data-required=true] input:not(:checked)")?.focus({ preventScroll: true });
    status.textContent = "Заполните два отмеченных вопроса, чтобы отправить анкету.";
    return;
  }

  const answers = {};
  for (const [name, value] of new FormData(form)) {
    if (name === "website") {
      answers.website = value;
      continue;
    }
    const input = form.querySelector(`[name="${CSS.escape(name)}"]`);
    if (input?.type === "checkbox") {
      (answers[name] ??= []).push(value);
    } else {
      answers[name] = value.trim();
    }
  }

  submitButton.disabled = true;
  submitButton.querySelector("span").textContent = "Отправляем…";
  try {
    const response = await fetch("/playtest/api/submit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ answers }),
      credentials: "same-origin",
      cache: "no-store",
    });
    if (response.status === 409) {
      showSubmitted(true);
      return;
    }
    if (!response.ok) throw new Error("submit_failed");
    showSubmitted(false);
  } catch {
    status.textContent = "Не удалось отправить ответы. Проверьте подключение и попробуйте ещё раз.";
    submitButton.disabled = false;
    submitButton.querySelector("span").textContent = "Отправить ответы";
  }
});

function showSubmitted(already) {
  form.hidden = true;
  document.querySelector(".progress-wrap").hidden = true;
  successPanel.hidden = false;
  if (already) {
    successPanel.querySelector(".eyebrow").textContent = "АНКЕТА УЖЕ ОТПРАВЛЕНА";
    successPanel.querySelector("h2").textContent = "Спасибо за участие.";
    successPanel.querySelector("p").textContent = "Мы уже получили ответы из этой сессии. Повторная отправка закрыта.";
  }
  successPanel.scrollIntoView({ behavior: "smooth", block: "center" });
}

async function openSession() {
  try {
    const response = await fetch("/playtest/api/session", {
      credentials: "same-origin",
      cache: "no-store",
    });
    if (!response.ok) throw new Error("session_failed");
    const result = await response.json();
    if (result.submitted) {
      showSubmitted(true);
      return;
    }
    sessionReady = true;
    submitButton.disabled = false;
    status.textContent = "";
  } catch {
    status.textContent = "Не удалось открыть анкету. Обновите страницу и попробуйте ещё раз.";
  }
}

updateProgress();
openSession();
