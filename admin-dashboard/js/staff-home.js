import { ref, onValue } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml } from "./html-utils.js";
import { toEntries, needsPaymentCheck } from "./new-order-logic.js";

// Overview shown to staff after sign-in: what needs doing right now.
// Only reads data staff may already read (orders, products, chat threads), so
// it needs no extra database access. Admins keep the full Dashboard instead.

const LOW_STOCK_LIMIT = 5;

function $(id) {
  return document.getElementById(id);
}

function setText(id, value) {
  const el = $(id);
  if (el) el.textContent = value;
}

// Same meaning as returnState() in returns.js: a return nobody has decided yet.
function isOpenReturn(order) {
  const hasReturn = (order.returnReason || '') !== '' || order.status === 'Returned';
  if (!hasReturn) return false;
  if (order.refundStatus === 'refunded' || order.refundStatus === 'refund_pending') return false;
  if (order.returnStatus === 'rejected' || order.status === 'Returned') return false;
  return true;
}

// Same rule as isUnread() in chats.js.
function isUnreadThread(thread) {
  return !!thread && thread.lastFromAdmin !== true && (thread.lastTimestamp || 0) > (thread.adminReadAt || 0);
}

export function initStaffHome() {
  // Cards are buttons that open the matching screen.
  $('staff-home-tab')?.addEventListener('click', (event) => {
    const card = event.target.closest('[data-go]');
    if (card) window.switchTab(card.dataset.go);
  });

  let firstOrders = true;

  onValue(ref(db, 'transactions'), (snapshot) => {
    const orders = toEntries(snapshot.val()).map(([, order]) => order);
    const pending = orders.filter((o) => (o.status || 'Pending') === 'Pending');
    const toVerify = pending.filter(needsPaymentCheck);
    const returns = orders.filter(isOpenReturn);
    const toReceive = returns.filter((o) => !o.returnReceivedAt);

    setText('sh-pending', pending.length);
    setText('sh-verify', toVerify.length);
    setText('sh-returns', returns.length);
    setText('sh-returns-sub', returns.length ? `${toReceive.length} item(s) not yet received` : '');

    if (firstOrders) {
      firstOrders = false;
      window.hideLoading('staff-home');
    }
  }, (err) => {
    console.error('Staff overview: could not load orders:', err);
    window.hideLoading('staff-home');
  });

  onValue(ref(db, 'chatThreads'), (snapshot) => {
    const threads = Object.values(snapshot.val() || {});
    setText('sh-chats', threads.filter(isUnreadThread).length);
  }, (err) => console.error('Staff overview: could not load chats:', err));

  onValue(ref(db, 'products'), (snapshot) => {
    const low = Object.values(snapshot.val() || {})
      .filter((p) => p && typeof p === 'object')
      .map((p) => ({
        name: p.productName || p.name || 'Unnamed product',
        stock: parseInt(p.productStock ?? p.stock ?? 0, 10) || 0
      }))
      .filter((p) => p.stock <= LOW_STOCK_LIMIT)
      .sort((a, b) => a.stock - b.stock);

    setText('sh-lowstock', low.length);

    const body = $('sh-lowstock-body');
    if (!body) return;
    if (low.length === 0) {
      body.innerHTML = '<tr><td colspan="2" style="text-align:center; color:#64748b;">Everything is well stocked.</td></tr>';
      return;
    }
    body.innerHTML = low.slice(0, 8).map((p) => `
      <tr>
        <td style="font-weight:600;">${escapeHtml(p.name)}</td>
        <td>${p.stock === 0
          ? '<span class="badge badge-cancelled">Out of stock</span>'
          : `<span class="badge badge-pending">${p.stock} left</span>`}</td>
      </tr>`).join('') +
      (low.length > 8 ? `<tr><td colspan="2" style="color:#64748b; font-size:12px;">…and ${low.length - 8} more in Inventory.</td></tr>` : '');
  }, (err) => console.error('Staff overview: could not load products:', err));
}
