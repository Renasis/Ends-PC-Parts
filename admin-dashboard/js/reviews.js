import { notify } from "./toast.js";
import { ref, onValue, remove, update } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";

let rawProductsData = {};
let activeReplyTarget = null; // Stores { productId, reviewId }

export function initReviewsModule() {
  const productsRef = ref(db, 'products');

  onValue(productsRef, (snapshot) => {
    rawProductsData = snapshot.val() || {};
    renderReviewsDashboard();
    window.hideLoading('reviews');
  });

  document.getElementById('rev-search-input')?.addEventListener('input', renderReviewsTable);
}

function getFlattenedReviewsList() {
  let allReviews = [];

  if (!rawProductsData || typeof rawProductsData !== 'object') return allReviews;

  Object.entries(rawProductsData).forEach(([productId, productObj]) => {
    if (!productObj || typeof productObj !== 'object') return;
    const productName = productObj.productName || productObj.name || 'PC Part Item';
    const productReviews = productObj.reviews;

    if (productReviews && typeof productReviews === 'object') {
      Object.entries(productReviews).forEach(([reviewId, rev]) => {
        if (rev && typeof rev === 'object') {
          allReviews.push({
            reviewId: reviewId,
            productId: productId,
            productName: productName,
            customerName: rev.userName || rev.customerName || 'Anonymous',
            rating: parseInt(rev.rating || rev.score || 5, 10),
            comment: rev.comment || rev.review || 'No comment provided.',
            adminReply: rev.adminReply || rev.reply || null,
            timestamp: rev.timestamp || 0
          });
        }
      });
    }
  });

  return allReviews;
}

function renderReviewsDashboard() {
  const reviewList = getFlattenedReviewsList();
  const totalReviews = reviewList.length;
  let totalRatingSum = 0;

  reviewList.forEach((rev) => {
    totalRatingSum += rev.rating;
  });

  const avgRating = totalReviews > 0 ? (totalRatingSum / totalReviews).toFixed(1) : '0.0';

  const totalEl = document.getElementById('rev-stat-total');
  const avgEl = document.getElementById('rev-stat-avg');

  if (totalEl) totalEl.innerText = totalReviews;
  if (avgEl) avgEl.innerText = `${avgRating} / 5.0`;

  renderReviewsTable();
}

function renderReviewsTable() {
  const tbody = document.getElementById('reviews-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('rev-search-input')?.value || '').toLowerCase();
  const reviewList = getFlattenedReviewsList();

  let filtered = reviewList.filter((rev) => {
    return rev.productName.toLowerCase().includes(searchQuery) ||
           rev.customerName.toLowerCase().includes(searchQuery) ||
           rev.comment.toLowerCase().includes(searchQuery);
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#64748b;">No customer reviews found.</td></tr>';
    return;
  }

  filtered.sort((a, b) => b.timestamp - a.timestamp);

  const fragment = document.createDocumentFragment();

  filtered.forEach((rev) => {
    const stars = '★'.repeat(Math.min(5, Math.max(1, rev.rating))) + '☆'.repeat(Math.max(0, 5 - Math.min(5, Math.max(1, rev.rating))));
    
    let commentHtml = `<div>${escapeHtml(rev.comment)}</div>`;
    if (rev.adminReply) {
      commentHtml += `<div style="margin-top: 4px; font-size: 12px; color: #2563eb; background: #eff6ff; padding: 4px 8px; border-radius: 4px;"><strong>Admin Reply:</strong> ${escapeHtml(rev.adminReply)}</div>`;
    }

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="font-weight:600; color:#1e293b;">${escapeHtml(rev.productName)}</td>
      <td>${escapeHtml(rev.customerName)}</td>
      <td><span style="color:#f59e0b; font-weight:bold; letter-spacing:1px;">${stars}</span> (${rev.rating}/5)</td>
      <td style="max-width: 280px;" title="${rev.comment}">${commentHtml}</td>
      <td>
        <div style="display: flex; gap: 6px;">
          <button class="btn btn-secondary admin-only" style="padding: 4px 10px; font-size: 12px;" onclick="window.openReplyModal(${jsArg(rev.productId)}, ${jsArg(rev.reviewId)}, ${jsArg(encodeURIComponent(rev.customerName))}, ${jsArg(encodeURIComponent(rev.comment))})">Reply</button>
          <button class="btn btn-danger" style="padding: 4px 10px; font-size: 12px;" onclick="window.deleteReviewModule(${jsArg(rev.productId)}, ${jsArg(rev.reviewId)})">Remove</button>
        </div>
      </td>
    `;
    fragment.appendChild(tr);
  });

  tbody.appendChild(fragment);
}

window.openReplyModal = function(productId, reviewId, encodedCustomer, encodedComment) {
  if (document.body.classList.contains('role-staff')) return; // staff can read and remove, not reply
  activeReplyTarget = { productId, reviewId };
  document.getElementById('reply-modal-customer').innerText = decodeURIComponent(encodedCustomer);
  document.getElementById('reply-modal-comment').innerText = decodeURIComponent(encodedComment);
  document.getElementById('admin-reply-input').value = '';
  document.getElementById('reply-modal').classList.add('active');
};

window.closeReplyModal = function() {
  document.getElementById('reply-modal').classList.remove('active');
  activeReplyTarget = null;
};

window.submitAdminReply = async function(event) {
  event.preventDefault();
  if (!activeReplyTarget) return;

  const replyText = document.getElementById('admin-reply-input').value.trim();
  if (!replyText) return;

  const { productId, reviewId } = activeReplyTarget;
  const reviewRef = ref(db, `products/${productId}/reviews/${reviewId}`);

  try {
    await update(reviewRef, { adminReply: replyText });
    window.closeReplyModal();
  } catch (err) {
    console.error("Failed to submit admin reply:", err);
    notify("Failed to send reply. Please check your network connection.");
  }
};

window.deleteReviewModule = function(productId, reviewId) {
  if (confirm("Are you sure you want to remove this review?")) {
    remove(ref(db, `products/${productId}/reviews/${reviewId}`)).catch((err) => {
      console.error("Failed to delete review:", err);
      notify("Failed to delete review.");
    });
  }
};