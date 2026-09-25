"use strict";

const reviewForm = document.getElementById("review-form");
const reviewStatus = document.getElementById("review-status");
const reviewSubmit = document.getElementById("review-submit");
const publishedReviews = document.getElementById("published-reviews");

function reviewCard(review) {
  const card = document.createElement("article");
  card.className = "review-card";

  const heading = document.createElement("div");
  heading.className = "review-card-heading";
  const author = document.createElement("strong");
  author.textContent = review.author;
  heading.append(author);

  if (Number.isInteger(review.rating) && review.rating >= 1 && review.rating <= 5) {
    const rating = document.createElement("span");
    rating.className = "review-stars";
    rating.textContent = "★".repeat(review.rating) + "☆".repeat(5 - review.rating);
    rating.setAttribute("aria-label", `Оценка ${review.rating} из 5`);
    heading.append(rating);
  }
  card.append(heading);

  const body = document.createElement("p");
  body.textContent = review.body;
  card.append(body);

  const date = new Date(review.published_at);
  if (!Number.isNaN(date.getTime())) {
    const time = document.createElement("time");
    time.dateTime = review.published_at;
    time.textContent = new Intl.DateTimeFormat("ru-RU", {
      day: "numeric", month: "long", year: "numeric",
    }).format(date);
    card.append(time);
  }
  return card;
}

async function loadPublishedReviews() {
  try {
    const response = await fetch("/playtest/api/reviews", { credentials: "same-origin" });
    if (!response.ok) throw new Error("load_failed");
    const data = await response.json();
    publishedReviews.replaceChildren();
    if (!Array.isArray(data.reviews) || data.reviews.length === 0) {
      const empty = document.createElement("p");
      empty.className = "review-empty";
      empty.textContent = "Пока нет опубликованных отзывов. Ваш может стать первым.";
      publishedReviews.append(empty);
      return;
    }
    for (const review of data.reviews) publishedReviews.append(reviewCard(review));
  } catch {
    const error = document.createElement("p");
    error.className = "review-empty";
    error.textContent = "Не удалось загрузить отзывы. Попробуйте позже.";
    publishedReviews.replaceChildren(error);
  }
}

reviewForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  reviewStatus.classList.remove("is-success");
  reviewStatus.textContent = "";
  reviewSubmit.disabled = true;
  try {
    const session = await fetch("/playtest/api/session", { credentials: "same-origin" });
    if (!session.ok) throw new Error("session_failed");
    const response = await fetch("/playtest/api/reviews", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        author: reviewForm.elements.author.value,
        rating: reviewForm.elements.rating.value,
        body: reviewForm.elements.body.value,
        website: reviewForm.elements.website.value,
      }),
    });
    if (response.status === 409) {
      reviewStatus.textContent = "Из этого браузера отзыв уже отправлен.";
    } else if (!response.ok) {
      throw new Error("submit_failed");
    } else {
      reviewForm.reset();
      reviewStatus.classList.add("is-success");
      reviewStatus.textContent = "Спасибо! Отзыв отправлен на проверку и пока не опубликован.";
    }
  } catch {
    reviewStatus.textContent = "Не удалось отправить отзыв. Попробуйте ещё раз позже.";
  } finally {
    reviewSubmit.disabled = false;
  }
});

loadPublishedReviews();
