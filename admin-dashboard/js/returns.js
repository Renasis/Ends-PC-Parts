import { notify } from "./toast.js";
import { ref, onValue, update, get } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db, auth } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";
import { notifyReturnApproved, notifyReturnRejected, notifyRefundProcessed } from "./notifications.js";
import { processOrderStatusChange } from "./orders.js";

// Return flow
//   1. Customer asks for a return in the app: reason, optional photo and the
//      account the refund should go to (returnStatus = 'requested').
//   2. Admin opens "Review", reads the reason, looks at the photo, then either
//      - approves: sets the refund amount, order becomes Returned and
//        refundStatus = 'refund_pending', or
//      - declines: returnStatus = 'rejected' with a note for the customer.
//   3. There is no payment gateway, so the admin sends the money by hand to the
//      customer's GCash / Maya / bank account, then types the transaction
//      reference number and marks it refunded (refundStatus = 'refunded').

let allOrders = {};      // every order, so an admin-started return can be reviewed too
let returnsCache = {};   // only orders that have a return
let openReviewId = null;
let openReviewState = null;

// Staff can look at every return and record that the item arrived, but only an
// admin can approve, decline or refund (database.rules.json enforces it too).
const isStaff = () => document.body.classList.contains('role-staff');

const peso = (n) => `₱${(Number(n) || 0).toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const shortId = (id) => String(id).substring(0, 8);

// 'requested' | 'refund_pending' | 'refunded' | 'rejected'
function returnState(ord) {
  if (ord.refundStatus === 'refunded') return 'refunded';
  if (ord.refundStatus === 'refund_pending') return 'refund_pending';
  if (ord.returnStatus === 'rejected') return 'rejected';
  if (ord.status === 'Returned') return 'refund_pending'; // returns made before returnStatus existed
  return 'requested';
}

const STATE_UI = {
  requested:      { label: 'Needs Review',   badge: 'badge-pending' },
  refund_pending: { label: 'Refund to Send', badge: 'badge-processing' },
  refunded:       { label: 'Refunded',       badge: 'badge-completed' },
  rejected:       { label: 'Declined',       badge: 'badge-cancelled' }
};

function hasReturn(ord) {
  return !!ord && ((ord.returnReason || '') !== '' || ord.status === 'Returned');
}

function totalOf(ord) {
  let raw = ord.grandTotal ?? 0;
  if (typeof raw === 'string') raw = raw.replace(/[^0-9.-]+/g, '');
  return parseFloat(raw) || 0;
}

function itemsOf(ord) {
  const list = Array.isArray(ord.items) ? ord.items : Object.values(ord.items || {});
  return list.filter((it) => it && typeof it === 'object');
}

// Only data: URLs for images are shown; anything else in the field is ignored.
function proofImageOf(ord) {
  const url = ord.returnImageUrl;
  return typeof url === 'string' && url.startsWith('data:image/') ? url : '';
}

export function initReturnsModule() {
  onValue(ref(db, 'transactions'), (snapshot) => {
    const data = snapshot.val() || {};
    allOrders = {};
    const returns = {};

    Object.entries(data).forEach(([id, ord]) => {
      if (!ord) return;
      allOrders[id] = ord;
      if (hasReturn(ord)) returns[id] = ord;
    });

    returnsCache = returns;
    renderReturnsTable();
    refreshOpenReview();
    window.hideLoading('returns');
  });

  document.getElementById('r-search-input')?.addEventListener('input', renderReturnsTable);
  document.getElementById('r-filter-status')?.addEventListener('change', renderReturnsTable);

  window.addEventListener('click', (e) => {
    if (e.target === document.getElementById('return-review-modal')) window.closeReturnReview();
  });
}

// ------------------------------------------------------------------ table

function renderReturnsTable() {
  const tbody = document.getElementById('returns-table-body');
  if (!tbody) return;

  const searchQuery = (document.getElementById('r-search-input')?.value || '').toLowerCase();
  const selectedStatus = document.getElementById('r-filter-status')?.value || 'ALL';

  const entries = Object.entries(returnsCache);
  const needsReview = entries.filter(([, o]) => returnState(o) === 'requested').length;
  const toSend = entries.filter(([, o]) => returnState(o) === 'refund_pending').length;
  const summary = document.getElementById('returns-summary');
  if (summary) {
    const toReceive = entries.filter(([, o]) => returnState(o) === 'requested' && !o.returnReceivedAt).length;
    summary.textContent = `${needsReview} waiting for review · ${toReceive} item(s) not yet received · ${toSend} approved, refund still to send`;
  }

  // newest request first
  entries.sort(([, a], [, b]) => (b.returnedAt || b.createdAt || 0) - (a.returnedAt || a.createdAt || 0));

  const wanted = { REQUESTED: 'requested', PENDING_REFUND: 'refund_pending', REFUNDED: 'refunded', REJECTED: 'rejected' }[selectedStatus];

  const filtered = entries.filter(([id, ord]) => {
    const recipient = (ord.recipientName || '').toLowerCase();
    const matchesSearch = recipient.includes(searchQuery) || String(id).toLowerCase().includes(searchQuery);
    const matchesStatus = !wanted || returnState(ord) === wanted;
    return matchesSearch && matchesStatus;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:#64748b;">No return requests found.</td></tr>';
    return;
  }

  const fragment = document.createDocumentFragment();

  filtered.forEach(([id, ord]) => {
    const state = returnState(ord);
    const ui = STATE_UI[state];
    const when = ord.returnedAt > 0 ? new Date(ord.returnedAt).toLocaleDateString() : 'N/A';
    const reason = String(ord.returnReason || '');
    const reasonShort = reason.length > 50 ? `${reason.substring(0, 50)}…` : reason;
    const photo = (proofImageOf(ord) ? ' <span title="Photo attached" aria-label="Photo attached">📷</span>' : '') +
      (ord.returnReceivedAt ? ' <span title="Item received" aria-label="Item received">📦</span>' : '');
    const labels = isStaff()
      ? { requested: ord.returnReceivedAt ? 'View' : 'Receive Item', refund_pending: 'View', refunded: 'View', rejected: 'View' }
      : { requested: 'Review', refund_pending: 'Send Refund', refunded: 'View', rejected: 'View' };
    const actionLabel = labels[state];
    const actionClass = (actionLabel === 'Review' || actionLabel === 'Receive Item') ? 'btn-warning' : actionLabel === 'Send Refund' ? 'btn-primary' : 'btn-outline';
    const open = `event.stopPropagation(); window.openReturnReview(${jsArg(id)})`;

    const tr = document.createElement('tr');
    tr.className = 'clickable-row';
    tr.setAttribute('onclick', open);
    tr.innerHTML = `
      <td style="color:#2563eb; font-size:12px; font-weight:600;">#${escapeHtml(shortId(id))}</td>
      <td style="font-weight:600;">${escapeHtml(ord.recipientName || 'N/A')}</td>
      <td>${escapeHtml(when)}</td>
      <td>${peso(totalOf(ord))}</td>
      <td title="${escapeHtml(reason)}" style="max-width:220px;">${escapeHtml(reasonShort) || '<span style="color:#94a3b8;">-</span>'}${photo}</td>
      <td><span class="badge ${ui.badge}" style="font-size:11px;padding:2px 6px;">${ui.label}</span></td>
      <td style="text-align:center;">
        <button class="btn ${actionClass}" style="padding:4px 10px;font-size:12px;" onclick="${open}" aria-label="${actionLabel} return for order ${escapeHtml(id)}">${actionLabel}</button>
      </td>
    `;
    fragment.appendChild(tr);
  });

  tbody.innerHTML = '';
  tbody.appendChild(fragment);
}

// ----------------------------------------------------------------- review

window.openReturnReview = function (orderId) {
  const ord = allOrders[orderId];
  if (!ord) {
    notify('Order not found.');
    return;
  }
  openReviewId = orderId;
  renderReview();
  document.getElementById('return-review-modal')?.classList.add('active');
};

window.closeReturnReview = function () {
  document.getElementById('return-review-modal')?.classList.remove('active');
  openReviewId = null;
  openReviewState = null;
};

// Another admin (or the customer) changed the order while the window is open.
function refreshOpenReview() {
  if (!openReviewId) return;
  const ord = allOrders[openReviewId];
  if (!ord) {
    window.closeReturnReview();
    return;
  }
  if (returnState(ord) !== openReviewState) renderReview(); // keep typed values otherwise
}

function row(label, valueHtml) {
  return `<div style="display:flex; gap:8px; font-size:14px; margin-bottom:4px;"><span style="color:#64748b; min-width:120px;">${label}</span><span style="font-weight:600; color:#0f172a; word-break:break-word;">${valueHtml}</span></div>`;
}

function copyButton(text) {
  return `<button type="button" class="btn btn-outline btn-sm" style="margin-left:8px;" onclick="window.rvCopy(${jsArg(text)}, this)">Copy</button>`;
}

window.rvCopy = async function (text, btn) {
  try {
    await navigator.clipboard.writeText(text);
    if (btn) { btn.textContent = 'Copied'; setTimeout(() => { btn.textContent = 'Copy'; }, 1500); }
  } catch {
    notify('Could not copy. Select the text and copy it manually.');
  }
};

function renderReview() {
  const orderId = openReviewId;
  const ord = allOrders[orderId];
  const body = document.getElementById('rv-body');
  if (!ord || !body) return;

  const state = returnState(ord);
  openReviewState = state;
  const ui = STATE_UI[state];
  const total = totalOf(ord);
  const hasCustomerRequest = !!ord.returnReason;
  const isCod = String(ord.paymentMethod || 'COD').toLowerCase() === 'cod';
  const photo = proofImageOf(ord);
  const hasDestination = !!(ord.refundMethod && ord.refundAccountNumber);

  document.getElementById('rv-title').textContent = `Return · Order #${shortId(orderId)}`;

  const items = itemsOf(ord).map((it) => `
    <tr>
      <td style="padding:4px 8px;">${escapeHtml(it.productName || 'Item')}</td>
      <td style="padding:4px 8px; text-align:center;">× ${escapeHtml(it.quantity ?? 1)}</td>
      <td style="padding:4px 8px; text-align:right;">${peso(it.price)}</td>
    </tr>`).join('');

  // ---- what the customer told us
  const reasonBlock = hasCustomerRequest
    ? `<div style="background:#fffbeb; border:1px solid #fcd34d; border-radius:8px; padding:12px; font-size:14px; color:#78350f; white-space:pre-wrap; word-break:break-word;">${escapeHtml(ord.returnReason)}</div>`
    : `<div class="form-group full mb-16" style="margin:0;">
         <textarea class="field-input" id="rv-reason" rows="2" maxlength="500" placeholder="No customer request on file. Enter the reason for this return (required)."></textarea>
       </div>`;

  const photoBlock = photo
    ? `<img id="rv-photo" src="${escapeHtml(photo)}" alt="Photo submitted by the customer" title="Click to enlarge"
            style="max-width:240px; max-height:320px; border:1px solid #cbd5e1; border-radius:8px; cursor:zoom-in; display:block;"
            onclick="const full = this.style.maxWidth === '100%'; this.style.maxWidth = full ? '240px' : '100%'; this.style.maxHeight = full ? '320px' : 'none'; this.style.cursor = full ? 'zoom-in' : 'zoom-out';">`
    : '<p style="margin:0; font-size:13px; color:#64748b;">No photo was uploaded with this request.</p>';

  // ---- where the refund goes
  let destinationBlock;
  if (hasDestination) {
    destinationBlock = `
      ${row('Method', escapeHtml(ord.refundMethod))}
      ${row('Account name', escapeHtml(ord.refundAccountName || ''))}
      ${row('Account / mobile no.', `${escapeHtml(ord.refundAccountNumber)}${copyButton(ord.refundAccountNumber)}`)}`;
  } else if (state === 'requested' && isStaff()) {
    destinationBlock = '<p style="margin:0; font-size:13px; color:#92400e;">The customer did not give a refund account. An admin will ask for it before approving.</p>';
  } else if (state === 'requested') {
    destinationBlock = `
      <p style="margin:0 0 8px; font-size:13px; color:#92400e;">The customer did not give a refund account. Ask them (chat/phone: ${escapeHtml(ord.phoneNumber || 'N/A')}) and enter it here.</p>
      <div style="display:grid; gap:8px;">
        <input class="field-input" id="rv-method" placeholder="Refund method, e.g. GCash, Maya, Bank Transfer - BPI" maxlength="80">
        <input class="field-input" id="rv-acct-name" placeholder="Account holder name" maxlength="100">
        <input class="field-input" id="rv-acct-no" placeholder="Account / mobile number" maxlength="30">
      </div>`;
  } else {
    destinationBlock = '<p style="margin:0; font-size:13px; color:#64748b;">No refund account on file.</p>';
  }

  const paidWith = isCod
    ? 'Cash on Delivery (the customer paid cash, so the refund must go to an e-wallet or bank account)'
    : `${escapeHtml(ord.paymentMethod)}${ord.referenceNumber ? ` · ref ${escapeHtml(ord.referenceNumber)}` : ''}`;

  // ---- the decision area depends on where the return is
  let action = '';
  const itemsOnly = Math.max(0, (Number(ord.subtotal) || 0) - (Number(ord.discount) || 0));

  if (isStaff() && (state === 'requested' || state === 'refund_pending')) {
    const msg = state === 'requested'
      ? 'Only an admin can approve or decline a return and set the refund. When the item arrives, record it above and an admin will decide.'
      : `An admin approved this return (refund ${peso(ord.refundAmount)}) and will send the money.`;
    action = `<h4 style="margin:20px 0 8px;">Decision</h4><p style="margin:0; font-size:13px; color:#475569;">${msg}</p>`;
  } else if (state === 'requested') {
    action = `
      <h4 style="margin:20px 0 8px;">Decision</h4>
      <div class="form-group full mb-16">
        <label for="rv-amount">Refund amount (PHP)</label>
        <input class="field-input" type="number" id="rv-amount" min="0.01" max="${total.toFixed(2)}" step="0.01" value="${total.toFixed(2)}">
        <div style="margin-top:6px; display:flex; gap:8px; flex-wrap:wrap;">
          <button type="button" class="btn btn-outline btn-sm" onclick="document.getElementById('rv-amount').value='${total.toFixed(2)}'">Full order (${peso(total)})</button>
          ${itemsOnly > 0 && Math.abs(itemsOnly - total) > 0.005
            ? `<button type="button" class="btn btn-outline btn-sm" onclick="document.getElementById('rv-amount').value='${itemsOnly.toFixed(2)}'">Items only (${peso(itemsOnly)})</button>` : ''}
        </div>
        <small style="color:#64748b;">Cannot be more than the ${peso(total)} the customer paid.</small>
      </div>
      <label style="display:flex; gap:8px; align-items:center; font-size:13px; margin-bottom:16px;">
        <input type="checkbox" id="rv-restock" ${ord.returnCondition === 'damaged' ? '' : 'checked'}>
        Put the items back in stock (untick if they are damaged or unsellable)${ord.returnCondition === 'damaged' ? ' <strong style="color:#b91c1c;">Staff marked it damaged.</strong>' : ''}
      </label>
      <div class="form-group full mb-16">
        <label for="rv-note">Message to the customer ${hasCustomerRequest ? '(required if you decline)' : '(optional)'}</label>
        <textarea class="field-input" id="rv-note" rows="2" maxlength="200" placeholder="e.g., Photo shows the damage. Or: item works fine per our test, so we can't accept this return."></textarea>
      </div>
      <div class="row-end-gap-8">
        ${hasCustomerRequest ? `<button type="button" class="btn btn-danger" id="rv-reject-btn" onclick="window.rejectReturn(${jsArg(orderId)})">Decline return</button>` : ''}
        <button type="button" class="btn btn-success" id="rv-approve-btn" onclick="window.approveReturn(${jsArg(orderId)})">Approve return</button>
      </div>`;
  } else if (state === 'refund_pending') {
    action = `
      <h4 style="margin:20px 0 8px;">Send the refund</h4>
      <div style="background:#eff6ff; border:1px solid #bfdbfe; border-radius:8px; padding:12px; font-size:14px; margin-bottom:12px;">
        Send <strong>${peso(ord.refundAmount)}</strong> to the account above using your own ${escapeHtml(ord.refundMethod || 'GCash / Maya / bank')} app,
        then enter the transaction reference number it gives you.
      </div>
      <div class="form-group full mb-16">
        <label for="rv-ref">Transaction reference number</label>
        <input class="field-input" id="rv-ref" maxlength="60" placeholder="e.g., GCash reference no.">
      </div>
      <div class="row-end-gap-8">
        <button type="button" class="btn btn-success" id="rv-refund-btn" onclick="window.markReturnRefunded(${jsArg(orderId)})">I sent the money - mark as refunded</button>
      </div>`;
  } else if (state === 'refunded') {
    action = `
      <h4 style="margin:20px 0 8px;">Refund sent</h4>
      ${row('Amount', peso(ord.refundAmount))}
      ${row('Reference no.', escapeHtml(ord.refundReference || 'Not recorded'))}
      ${row('Sent on', ord.refundedAt ? escapeHtml(new Date(ord.refundedAt).toLocaleString()) : 'N/A')}`;
  } else if (state === 'rejected') {
    action = `
      <h4 style="margin:20px 0 8px;">Return declined</h4>
      ${row('Note to customer', escapeHtml(ord.returnAdminNote || 'None'))}
      ${ord.returnReviewedAt ? row('Decided on', escapeHtml(new Date(ord.returnReviewedAt).toLocaleString())) : ''}`;
  }

  // ---- the item arriving: recorded by staff (or an admin) before the decision
  let receiptBlock = '';
  if (ord.returnReceivedAt) {
    const damaged = ord.returnCondition === 'damaged';
    receiptBlock = `
      <h4 style="margin:18px 0 8px;">Item received</h4>
      <div style="background:${damaged ? '#fef2f2' : '#f0fdf4'}; border:1px solid ${damaged ? '#fecaca' : '#bbf7d0'}; border-radius:8px; padding:12px; font-size:14px;">
        <strong>${damaged ? 'Damaged / not resellable' : 'Good condition, can be resold'}</strong><br>
        <span style="font-size:12px; color:#64748b;">Received ${escapeHtml(new Date(ord.returnReceivedAt).toLocaleString())}${ord.returnReceivedBy ? ` by ${escapeHtml(ord.returnReceivedBy)}` : ''}</span>
        ${ord.returnReceivedNote ? `<div style="margin-top:6px; white-space:pre-wrap; word-break:break-word;">${escapeHtml(ord.returnReceivedNote)}</div>` : ''}
      </div>`;
  } else if (state === 'requested') {
    receiptBlock = `
      <h4 style="margin:18px 0 8px;">Item received?</h4>
      <div style="border:1px solid #e2e8f0; border-radius:8px; padding:12px;">
        <p style="margin:0 0 8px; font-size:13px; color:#475569;">When the customer's item arrives, check it and record its condition.</p>
        <div class="form-group full mb-16">
          <label for="rv-condition">Condition</label>
          <select class="field-input" id="rv-condition">
            <option value="good">Good - can be resold</option>
            <option value="damaged">Damaged / not resellable</option>
          </select>
        </div>
        <div class="form-group full mb-16">
          <label for="rv-recv-note">Inspection note (required if damaged)</label>
          <textarea class="field-input" id="rv-recv-note" rows="2" maxlength="300" placeholder="e.g., Sealed box, nothing missing. Or: GPU fan cracked."></textarea>
        </div>
        <div class="row-end-gap-8">
          <button type="button" class="btn btn-success" id="rv-received-btn" onclick="window.markReturnReceived(${jsArg(orderId)})">Mark item as received</button>
        </div>
      </div>`;
  }

  const approvedExtra = (state === 'refund_pending' || state === 'refunded') && ord.returnAdminNote
    ? row('Note to customer', escapeHtml(ord.returnAdminNote)) : '';

  body.innerHTML = `
    <div style="margin-bottom:12px;">
      <span class="badge ${ui.badge}">${ui.label}</span>
      ${ord.returnedAt > 0 ? `<span style="font-size:12px; color:#64748b; margin-left:8px;">Requested ${escapeHtml(new Date(ord.returnedAt).toLocaleString())}</span>` : ''}
    </div>

    ${row('Customer', escapeHtml(ord.recipientName || 'N/A'))}
    ${row('Contact', escapeHtml(ord.phoneNumber || ord.email || ord.userEmail || 'N/A'))}
    ${row('Paid with', paidWith)}
    ${row('Order total', peso(total))}
    ${approvedExtra}

    <table style="width:100%; margin:10px 0 4px; font-size:13px; border:1px solid #e2e8f0; border-radius:6px;">
      <tbody>${items || '<tr><td style="padding:6px 8px; color:#64748b;">No item details.</td></tr>'}</tbody>
    </table>

    <h4 style="margin:18px 0 8px;">Reason for return</h4>
    ${reasonBlock}

    <h4 style="margin:18px 0 8px;">Photo from the customer</h4>
    ${photoBlock}

    <h4 style="margin:18px 0 8px;">Refund goes to</h4>
    <div style="border:1px solid #e2e8f0; border-radius:8px; padding:12px;">${destinationBlock}</div>

    ${receiptBlock}

    ${action}
  `;
}

// --------------------------------------------------------------- decisions

function setBusy(ids, busy) {
  ids.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.disabled = busy;
  });
}

window.approveReturn = async function (orderId) {
  if (isStaff()) return;
  const ord = allOrders[orderId];
  if (!ord || returnState(ord) !== 'requested') return;

  const total = totalOf(ord);
  const amount = Math.round((parseFloat(document.getElementById('rv-amount')?.value) || 0) * 100) / 100;
  const note = (document.getElementById('rv-note')?.value || '').trim();
  const restock = document.getElementById('rv-restock')?.checked !== false;
  const reason = ord.returnReason || (document.getElementById('rv-reason')?.value || '').trim();

  if (!reason) { notify('Enter the reason for this return first.'); return; }
  if (!(amount > 0)) { notify('Enter a refund amount greater than zero.'); return; }
  if (amount > total + 0.005) { notify(`The refund cannot be more than the ${peso(total)} the customer paid.`); return; }

  // Refund account typed by the admin when the customer did not provide one.
  const fields = { returnStatus: 'approved', returnReviewedAt: Date.now() };
  if (note) fields.returnAdminNote = note;
  if (!ord.returnedAt) fields.returnedAt = Date.now();
  const destination = { refundMethod: ord.refundMethod, refundAccountName: ord.refundAccountName, refundAccountNumber: ord.refundAccountNumber };
  if (!ord.refundMethod || !ord.refundAccountNumber) {
    const method = (document.getElementById('rv-method')?.value || '').trim();
    const name = (document.getElementById('rv-acct-name')?.value || '').trim();
    const number = (document.getElementById('rv-acct-no')?.value || '').trim();
    if (method && name && number) {
      const typed = { refundMethod: method, refundAccountName: name, refundAccountNumber: number };
      Object.assign(fields, typed);
      Object.assign(destination, typed);
    }
  }

  if (!confirm(`Approve this return and refund ${peso(amount)} for order #${shortId(orderId)}?${restock ? '\nThe items will go back into stock.' : '\nThe items will NOT be restocked.'}`)) return;

  setBusy(['rv-approve-btn', 'rv-reject-btn'], true);
  const ok = await processOrderStatusChange(orderId, 'Returned', reason, false, amount, '', '', 0, 0, { restock, fields });
  if (!ok) {
    setBusy(['rv-approve-btn', 'rv-reject-btn'], false);
    return;
  }

  await notifyReturnApproved(orderId, { ...ord, ...destination }, amount, note);
  window.logAdminAction?.('RETURN_APPROVED', `Return for order #${shortId(orderId)} approved (${peso(amount)}).`);
  notify('Return approved. Now send the refund and record the reference number.');
  // the live listener refreshes the window into the "Send the refund" step
};

window.rejectReturn = async function (orderId) {
  if (isStaff()) return;
  const ord = allOrders[orderId];
  if (!ord || returnState(ord) !== 'requested') return;

  const note = (document.getElementById('rv-note')?.value || '').trim();
  if (note.length < 3) {
    notify('Write a short reason for declining so the customer knows why.');
    document.getElementById('rv-note')?.focus();
    return;
  }
  if (!confirm(`Decline the return for order #${shortId(orderId)}? The customer will see your message.`)) return;

  setBusy(['rv-approve-btn', 'rv-reject-btn'], true);
  try {
    const orderRef = ref(db, `transactions/${orderId}`);
    const fresh = (await get(orderRef)).val();
    if (!fresh || fresh.status !== 'Completed' || returnState(fresh) !== 'requested') {
      notify('This return was already handled.');
      setBusy(['rv-approve-btn', 'rv-reject-btn'], false);
      return;
    }
    await update(orderRef, {
      returnStatus: 'rejected',
      returnAdminNote: note,
      returnReviewedAt: Date.now(),
      refundAmount: 0,
      refundStatus: ''
    });
    await notifyReturnRejected(orderId, ord, note);
    window.logAdminAction?.('RETURN_DECLINED', `Return for order #${shortId(orderId)} declined.`);
    notify('Return declined and the customer was notified.');
  } catch (err) {
    console.error('Could not decline the return:', err);
    notify('Failed to decline the return. Please check your network connection.');
    setBusy(['rv-approve-btn', 'rv-reject-btn'], false);
  }
};

window.markReturnRefunded = async function (orderId) {
  if (isStaff()) return;
  const ord = allOrders[orderId];
  if (!ord || returnState(ord) !== 'refund_pending') return;

  const reference = (document.getElementById('rv-ref')?.value || '').trim();
  if (reference.length < 4) {
    notify('Enter the transaction reference number from your payment app.');
    document.getElementById('rv-ref')?.focus();
    return;
  }

  const amount = parseFloat(ord.refundAmount) || 0;
  const where = ord.refundMethod ? ` to ${ord.refundMethod} ${ord.refundAccountNumber || ''}` : '';
  if (!confirm(`Confirm you already sent ${peso(amount)}${where}?\nThe customer will be told the refund was sent.`)) return;

  setBusy(['rv-refund-btn'], true);
  try {
    await update(ref(db, `transactions/${orderId}`), {
      refundStatus: 'refunded',
      refundReference: reference,
      refundedAt: Date.now()
    });
    await notifyRefundProcessed(orderId, ord, amount, reference);
    window.logAdminAction?.('REFUND_SENT', `Refund of ${peso(amount)} for order #${shortId(orderId)} sent (ref ${reference}).`);
    notify('Refund recorded and the customer was notified.');
  } catch (err) {
    console.error('Could not record the refund:', err);
    notify('Failed to record the refund. Please check your network connection.');
    setBusy(['rv-refund-btn'], false);
  }
};

// Staff or admin: the returned item has arrived and been checked. This only
// records what was found; the admin still decides on the refund, and the
// "put back in stock" choice stays with the approval (so a declined return
// can never leave extra stock behind).
window.markReturnReceived = async function (orderId) {
  const ord = allOrders[orderId];
  if (!ord || returnState(ord) !== 'requested' || ord.returnReceivedAt) return;

  const condition = document.getElementById('rv-condition')?.value === 'damaged' ? 'damaged' : 'good';
  const note = (document.getElementById('rv-recv-note')?.value || '').trim();
  if (condition === 'damaged' && note.length < 3) {
    notify('Describe the damage so the admin can decide.');
    document.getElementById('rv-recv-note')?.focus();
    return;
  }
  if (!confirm(`Record that the item for order #${shortId(orderId)} was received in ${condition === 'damaged' ? 'DAMAGED' : 'good'} condition?`)) return;

  setBusy(['rv-received-btn'], true);
  try {
    await update(ref(db, `transactions/${orderId}`), {
      returnReceivedAt: Date.now(),
      returnReceivedBy: auth.currentUser?.email || '',
      returnCondition: condition,
      returnReceivedNote: note
    });
    window.logAdminAction?.('RETURN_ITEM_RECEIVED', `Returned item for order #${shortId(orderId)} received (${condition}).`);
    notify('Recorded. An admin can now review the return.');
  } catch (err) {
    console.error('Could not record the received item:', err);
    notify('Failed to save. Please check your network connection.');
    setBusy(['rv-received-btn'], false);
  }
};
