import { ref, onValue } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { showActionToast } from "./toast.js";
import { detectNewOrders, detectCustomerCancellations, describeOrder, needsPaymentCheck } from "./new-order-logic.js";

// Tells the admin when a customer places a new order: a popup with a
// "View" button, a chime, a red badge on Orders, the page title and (when the
// admin allowed it) a desktop notification while the tab is in the background.
// The first snapshot after sign-in only records the existing orders.

const PREF_KEY = 'orderAlerts';
const MAX_INDIVIDUAL_TOASTS = 3;

let knownIds = null;
let knownStatuses = null;
let unseen = 0;
let audioCtx = null;

// ---------------------------------------------------------------- preference

function alertsOn() {
  try { return localStorage.getItem(PREF_KEY) !== 'off'; } catch { return true; }
}

function saveAlerts(on) {
  try { localStorage.setItem(PREF_KEY, on ? 'on' : 'off'); } catch { /* private mode */ }
}

function renderToggle() {
  const btn = document.getElementById('order-alerts-btn');
  if (!btn) return;
  const on = alertsOn();
  btn.textContent = on ? '🔔 Order alerts: On' : '🔕 Order alerts: Off';
  btn.setAttribute('aria-pressed', String(on));
}

// ------------------------------------------------------------------ chime

function playChime() {
  if (!alertsOn()) return;
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const start = audioCtx.currentTime;
    [[880, 0], [1175, 0.18]].forEach(([freq, delay]) => {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, start + delay);
      gain.gain.exponentialRampToValueAtTime(0.25, start + delay + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + delay + 0.3);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(start + delay);
      osc.stop(start + delay + 0.32);
    });
  } catch (err) {
    console.warn('Could not play the order chime:', err);
  }
}

// ------------------------------------------------------------ badge + title

function ordersBadge() {
  let badge = document.getElementById('orders-nav-badge');
  if (badge) return badge;
  const item = document.querySelector('.menu-item[data-tab="orders"]');
  if (!item) return null;
  badge = document.createElement('span');
  badge.id = 'orders-nav-badge';
  badge.className = 'nav-badge';
  badge.hidden = true;
  item.appendChild(badge);
  return badge;
}

function refreshIndicators() {
  const badge = ordersBadge();
  if (badge) {
    badge.hidden = unseen === 0;
    badge.textContent = unseen > 99 ? '99+' : String(unseen);
    badge.setAttribute('aria-label', `${unseen} new order${unseen === 1 ? '' : 's'}`);
  }
  const base = document.title.replace(/^\(\d+\)\s*/, '');
  document.title = unseen > 0 && document.hidden ? `(${unseen}) ${base}` : base;
}

function clearUnseen() {
  unseen = 0;
  refreshIndicators();
}

function ordersTabIsOpen() {
  const tab = document.getElementById('orders-tab');
  return !document.hidden && !!tab && tab.classList.contains('active');
}

// ---------------------------------------------------------------- announce

function openOrder(id, order) {
  clearUnseen();
  if (needsPaymentCheck(order)) {
    window.switchTab?.('verification');
    return;
  }
  window.switchTab?.('orders');
  window.viewOrderDetailsModule?.(id);
}

function desktopNotify(title, body, onClick) {
  if (!alertsOn() || !document.hidden) return;
  if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
  try {
    const n = new Notification(title, { body, tag: 'new-order' });
    n.onclick = () => { window.focus(); onClick(); n.close(); };
  } catch (err) {
    console.warn('Could not show a desktop notification:', err);
  }
}

function announce(fresh) {
  if (!ordersTabIsOpen()) unseen += fresh.length;
  refreshIndicators();
  playChime();

  if (fresh.length > MAX_INDIVIDUAL_TOASTS) {
    const title = `${fresh.length} new orders`;
    showActionToast({
      title: `🛍️ ${title}`,
      message: 'Several orders arrived at once.',
      actionLabel: 'View orders',
      onAction: () => { clearUnseen(); window.switchTab?.('orders'); }
    });
    desktopNotify(title, 'Open the dashboard to review them.', () => window.switchTab?.('orders'));
    return;
  }

  fresh.forEach(([id, order]) => {
    const line = describeOrder(id, order);
    const check = needsPaymentCheck(order);
    showActionToast({
      title: '🛍️ New order',
      message: check ? `${line}\nPayment needs verification.` : line,
      actionLabel: check ? 'Verify payment' : 'View order',
      onAction: () => openOrder(id, order)
    });
    desktopNotify('New order', line, () => openOrder(id, order));
  });
}

// Tells the admin a customer cancelled their own order, with the reason.
function announceCancellations(cancelled) {
  playChime();

  if (cancelled.length > MAX_INDIVIDUAL_TOASTS) {
    showActionToast({
      title: `❌ ${cancelled.length} orders cancelled`,
      message: 'Customers cancelled several orders.',
      actionLabel: 'View orders',
      onAction: () => window.switchTab?.('orders')
    });
    return;
  }

  cancelled.forEach(([id, order]) => {
    showActionToast({
      title: '❌ Order cancelled by customer',
      message: `${describeOrder(id, order)}\nReason: ${order.cancellationReason || 'No reason given'}`,
      actionLabel: 'View order',
      onAction: () => {
        window.switchTab?.('orders');
        window.viewOrderDetailsModule?.(id);
      }
    });
  });
}

// -------------------------------------------------------------------- init

export function initNewOrderAlerts() {
  renderToggle();

  document.getElementById('order-alerts-btn')?.addEventListener('click', () => {
    const turningOn = !alertsOn();
    saveAlerts(turningOn);
    renderToggle();
    if (turningOn) {
      playChime(); // also unlocks audio in the browser
      if (typeof Notification !== 'undefined' && Notification.permission === 'default') {
        Notification.requestPermission();
      }
    }
  });

  // Looking at Orders or Verify Payments counts as having seen the new orders.
  const originalSwitchTab = window.switchTab;
  if (typeof originalSwitchTab === 'function') {
    window.switchTab = function (tabName, ...rest) {
      originalSwitchTab.call(this, tabName, ...rest);
      if (tabName === 'orders' || tabName === 'verification') clearUnseen();
    };
  }
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && ordersTabIsOpen()) unseen = 0;
    refreshIndicators();
  });

  // Same location the dashboard already reads, so Firebase shares one connection.
  onValue(ref(db, 'transactions'), (snapshot) => {
    const result = detectNewOrders(knownIds, snapshot.val());
    knownIds = result.known;
    if (result.fresh.length > 0) announce(result.fresh);

    const cancels = detectCustomerCancellations(knownStatuses, snapshot.val());
    knownStatuses = cancels.statuses;
    if (cancels.cancelled.length > 0) announceCancellations(cancels.cancelled);
  }, (err) => console.error('New-order alerts stopped:', err));
}
