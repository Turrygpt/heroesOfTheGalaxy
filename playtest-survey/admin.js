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
let reviews = [];

function showLogin() {
  loginPanel.hidden = false;
  dashboard.hidden = true;
  reviews = [];
}

function showDashboard() {
  loginPanel.hidden = true;
  dashboard.hidden = false;
  loginForm.reset();
  loginForm.elements.username.value = "admin";
  loginStatus.textContent = "";
  loadReviews();
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

fetch(`${ADMIN_API}/session`, { credentials: "same-origin" })
  .then((response) => response.ok ? response.json() : { authenticated: false })
  .then((data) => data.authenticated ? showDashboard() : showLogin())
  .catch(showLogin);
