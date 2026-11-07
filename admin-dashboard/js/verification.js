import { notify } from "./toast.js";
import { ref, onValue, update, get, query, limitToLast } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";
import { compareNewest } from "./new-order-logic.js";
import { processOrderStatusChange } from "./orders.js";
import { notifyPaymentResult } from "./notifications.js";

let rawTransactionsCache = {};
let pendingRejectOrderId = null;

export function initVerificationModule() {
  const transactionsRef = query(ref(db, 'transactions'), limitToLast(500));

  onValue(transactionsRef, (snapshot) => {
    rawTransactionsCache = snapshot.val() || {};
    renderVerificationDashboard();
    window.hideLoading('verification');
  });

  document.getElementById('verify-search-input')?.addEventListener('input', renderVerificationTable);
}

function paymentStatusOf(ord) {
  return ord.paymentStatus || ord.paymentVerificationStatus || '';
}

function isOnlinePayment(ord) {
  return (ord.paymentMethod || '').toLowerCase() !== 'cod';
}

// Only a live order can be verified: one the customer already cancelled
// keeps paymentStatus "pending_verification" but must not be approved.
function isPendingVerification(ord) {
  const status = ord.status || 'Pending';
  return isOnlinePayment(ord) && status === 'Pending' && paymentStatusOf(ord) === 'pending_verification';
}

function amountOf(ord) {
  let raw = ord.grandTotal ?? 0;
  if (typeof raw === 'string') raw = raw.replace(/[^0-9.-]+/g, '');
  return `₱${(parseFloat(raw) || 0).toFixed(2)}`;
}

// Set when the customer typed a reference number instead of uploading a screenshot.
function paidAtOf(ord) {
  if (!ord.paidAt) return '';
  return new Date(ord.paidAt).toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' });
}

// Online-payment orders whose proof is still waiting to be checked.
function getVerificationList() {
  let list = [];
  if (!rawTransactionsCache) return list;

  const entries = Array.isArray(rawTransactionsCache)
    ? rawTransactionsCache.map((ord, idx) => [idx, ord]).filter(([_, ord]) => ord !== null)
    : Object.entries(rawTransactionsCache);

  entries.forEach(([id, ord]) => {
    if (ord && isPendingVerification(ord)) list.push({ id, ...ord });
  });

  return list;
}

function renderVerificationDashboard() {
  const verifyList = getVerificationList();
  const pendingEl = document.getElementById('verify-stat-pending');
  if (pendingEl) pendingEl.innerText = verifyList.length;

  renderVerificationTable();
}

// New orders keep the screenshot at paymentProofs/{orderId} (hasProofImage);
// orders placed earlier still carry it inline as paymentProof.
function proofCell(ord) {
  if (ord.paymentProof || ord.receiptImage) {
    const inline = ord.paymentProof || ord.receiptImage;
    return `<img src="${escapeHtml(inline)}" alt="Proof" style="width: 45px; height: 45px; object-fit: cover; border-radius: 4px; border: 1px solid #cbd5e1; cursor: pointer;" onclick="window.viewPaymentProofModal(${jsArg(ord.id)})">`;
  }
  if (ord.hasProofImage) {
    return `<button class="btn btn-secondary" style="padding: 4px 10px; font-size: 12px;" onclick="window.viewPaymentProofModal(${jsArg(ord.id)})">View screenshot</button>`;
  }
  return '<span style="color:#64748b; font-size:12px;">No Image</span>';
}

function refNumberOf(ord) {
  return ord.referenceNumber || ord.refNumber || ord.accountNumber || 'N/A';
}

function decisionButtons(orderId) {
  const id = escapeHtml(orderId);
  return `
    <div style="display: flex; gap: 6px;">
      <button class="btn btn-primary" style="padding: 4px 10px; font-size: 12px; background-color: #166534;" onclick="window.approvePayment(${jsArg(id)})">Approve</button>
      <button class="btn btn-danger" style="padding: 4px 10px; font-size: 12px;" onclick="window.openRejectPaymentModal(${jsArg(id)})">Reject</button>
    </div>`;
}

function renderVerificationTable() {
  const tbody = document.getElementById('verification-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('verify-search-input')?.value || '').toLowerCase();
  const verifyList = getVerificationList();

  let filtered = verifyList.filter((ord) => {
    const idStr = String(ord.id).toLowerCase();
    const customer = (ord.recipientName || '').toLowerCase();
    const refNo = (ord.referenceNumber || ord.refNumber || '').toLowerCase();
    return idStr.includes(searchQuery) || customer.includes(searchQuery) || refNo.includes(searchQuery);
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:#64748b;">No pending payment verifications found.</td></tr>';
    return;
  }

  [...filtered].sort(compareNewest).forEach((ord) => { // newest first
    const customer = escapeHtml(ord.recipientName || 'N/A');
    const method = escapeHtml((ord.paymentMethod || 'GCash').toUpperCase());
    const refNo = escapeHtml(refNumberOf(ord));

    tbody.innerHTML += `
      <tr>
        <td style="font-weight:600; color:#2563eb;">#${escapeHtml(String(ord.id).substring(0, 8))}</td>
        <td>${customer}</td>
        <td style="font-weight:600;">${escapeHtml(amountOf(ord))}</td>
        <td><span class="badge badge-processing">${method}</span></td>
        <td style="font-weight:600;">${refNo}${paidAtOf(ord) ? `<div style="font-weight:400; font-size:12px; color:#64748b;">Paid ${escapeHtml(paidAtOf(ord))}</div>` : ''}</td>
        <td>${proofCell(ord)}</td>
        <td>${decisionButtons(ord.id)}</td>
      </tr>
    `;
  });
}

// Payment panel inside the Orders > Order Details popup, so a payment can be
// checked right where the admin is already looking at the order.
window.renderOrderPaymentReview = function(orderId, ord) {
  const card = document.getElementById('modal-payment-card');
  if (!card) return;

  if (!isOnlinePayment(ord)) {
    card.style.display = 'none';
    card.innerHTML = '';
    return;
  }

  const status = paymentStatusOf(ord);
  const withId = { id: orderId, ...ord };
  const proofRow = `
    <p style="margin-bottom: 6px; font-size: 14px;"><strong>Amount to match:</strong> ${escapeHtml(amountOf(ord))}</p>
    <p style="margin-bottom: 6px; font-size: 14px;"><strong>Reference No.:</strong> ${escapeHtml(refNumberOf(ord))}</p>
    ${paidAtOf(ord) ? `<p style="margin-bottom: 6px; font-size: 14px;"><strong>Paid on:</strong> ${escapeHtml(paidAtOf(ord))}</p>` : ''}
    <div style="margin-bottom: 10px; font-size: 14px;"><strong>Proof of payment:</strong> <span style="margin-left: 6px; vertical-align: middle;">${proofCell(withId)}</span></div>`;

  let html;
  if (status === 'pending_verification') {
    html = `
      <div style="background: #fffbeb; padding: 16px; border-radius: 8px; border: 1px solid #fcd34d;">
        <h4 style="margin-bottom: 10px; color: #92400e; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Payment Awaiting Verification</h4>
        ${proofRow}
        ${decisionButtons(orderId)}
      </div>`;
  } else if (status === 'rejected') {
    const rejectionReason = ord.paymentRejectionReason || ord.cancellationReason;
    const reason = rejectionReason ? escapeHtml(rejectionReason) : 'No reason recorded.';
    html = `
      <div style="background: #fee2e2; padding: 16px; border-radius: 8px; border: 1px solid #fca5a5;">
        <h4 style="margin-bottom: 10px; color: #991b1b; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Payment Rejected</h4>
        ${proofRow}
        <p style="font-size: 14px; color: #7f1d1d; margin: 0;"><strong>Reason:</strong> ${reason}</p>
      </div>`;
  } else if (status === 'verified') {
    html = `
      <div style="background: #f0fdf4; padding: 16px; border-radius: 8px; border: 1px solid #86efac;">
        <h4 style="margin-bottom: 10px; color: #166534; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Payment Verified</h4>
        ${proofRow}
      </div>`;
  } else {
    card.style.display = 'none';
    card.innerHTML = '';
    return;
  }

  card.innerHTML = html;
  card.style.display = 'block';
};

// ---- Decisions -------------------------------------------------------------

window.approvePayment = async function(orderId) {
  const shortId = String(orderId).substring(0, 8);
  if (!confirm(`Approve the payment for Order #${shortId}? The order will move to Processing.`)) return;

  const orderRef = ref(db, `transactions/${orderId}`);

  try {
    const snapshot = await get(orderRef);
    const ord = snapshot.val();
    if (!ord || !isPendingVerification(ord)) {
      notify('This payment was already handled.');
      return;
    }

    // Same path as the Orders status dropdown, so stock is deducted once.
    const moved = await processOrderStatusChange(orderId, 'Processing', null, false);
    if (!moved) return;

    await update(orderRef, { paymentStatus: 'verified', verifiedAt: Date.now() });
    await notifyPaymentResult(orderId, ord, true);
    window.logAdminAction?.('PAYMENT_VERIFIED', `Order #${shortId} payment was approved.`);
  } catch (err) {
    console.error('Failed to approve the payment:', err);
    notify('Failed to approve the payment.');
  }
};

window.openRejectPaymentModal = function(orderId) {
  pendingRejectOrderId = orderId;
  const modal = document.getElementById('reject-payment-modal');
  if (!modal) return;

  document.getElementById('reject-payment-order').innerText = `#${String(orderId).substring(0, 8)}`;
  document.getElementById('reject-payment-reason').value = '';
  modal.classList.add('active');
  document.getElementById('reject-payment-reason').focus();
};

window.closeRejectPaymentModal = function() {
  document.getElementById('reject-payment-modal')?.classList.remove('active');
  pendingRejectOrderId = null;
};

window.setRejectPaymentReason = function(text) {
  const input = document.getElementById('reject-payment-reason');
  if (input) input.value = text;
};

window.submitPaymentRejection = async function(event) {
  event.preventDefault();
  if (!pendingRejectOrderId) return;

  const reason = document.getElementById('reject-payment-reason').value.trim();
  if (!reason) {
    notify('Please enter the reason for rejecting this payment.');
    return;
  }
  if (reason.length > 500) {
    notify('Rejection reason must be 500 characters or less.');
    return;
  }

  const orderId = pendingRejectOrderId;
  const shortId = String(orderId).substring(0, 8);
  const orderRef = ref(db, `transactions/${orderId}`);

  try {
    const snapshot = await get(orderRef);
    const ord = snapshot.val();
    if (!ord || !isPendingVerification(ord)) {
      window.closeRejectPaymentModal();
      notify('This payment was already handled.');
      return;
    }

    // The customer sees this reason on the order in the app.
    await update(orderRef, {
      status: 'Payment Rejected',
      paymentStatus: 'rejected',
      // Kept apart from cancellationReason so a later cancellation does not erase it.
      paymentRejectionReason: reason,
      cancellationReason: '',
      verifiedAt: Date.now()
    });
    await notifyPaymentResult(orderId, ord, false, reason);

    window.closeRejectPaymentModal();
    window.logAdminAction?.('PAYMENT_REJECTED', `Order #${shortId} payment was rejected: ${reason}`);
  } catch (err) {
    console.error('Failed to reject the payment:', err);
    notify('Failed to reject the payment.');
  }
};

// Opens the payment screenshot of one order. Old orders have it inline;
// newer ones are loaded from paymentProofs/{orderId} only when opened.
window.viewPaymentProofModal = async function(orderId) {
  const order = rawTransactionsCache[orderId];
  let imageUrl = order?.paymentProof || order?.receiptImage || '';

  if (!imageUrl) {
    try {
      const snapshot = await get(ref(db, `paymentProofs/${orderId}`));
      imageUrl = snapshot.val() || '';
    } catch (err) {
      console.error('Failed to load the payment screenshot:', err);
      notify('Could not load the screenshot. Please try again.');
      return;
    }
  }

  if (!imageUrl) {
    notify('No screenshot was found for this order.');
    return;
  }

  let modal = document.getElementById('proof-modal');

  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'proof-modal';
    modal.className = 'modal';
    modal.style.zIndex = '1100';
    modal.innerHTML = `
      <div class="modal-content card" style="max-width: 400px; text-align: center;">
        <div class="modal-header">
          <h2>Payment Proof</h2>
          <span class="close-btn" onclick="document.getElementById('proof-modal').classList.remove('active')">&times;</span>
        </div>
        <div class="modal-body" style="padding: 10px;">
          <img id="proof-modal-img" src="" alt="Payment Slip" style="width: 100%; max-height: 400px; object-fit: contain; border-radius: 6px;">
        </div>
      </div>
    `;
    document.body.appendChild(modal);
  }

  document.getElementById('proof-modal-img').src = imageUrl;
  modal.classList.add('active');
};
