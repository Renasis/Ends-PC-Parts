import { notify } from "./toast.js";
import { ref, onValue, update, get, runTransaction, query, limitToLast, orderByChild } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { notifyOrderStatus, notifyOrderShipped } from "./notifications.js";
import { escapeHtml, jsArg } from "./html-utils.js";
import { newestFirst } from "./new-order-logic.js";

let globalOrdersCache = {};
let pendingCancelOrderId = null;
let openOrderId = null;
let pendingShipOrderId = null;
let selectedOrderIds = new Set();

function isPaymentRejected(ord) {
  const paymentStatus = ord.paymentStatus || ord.paymentVerificationStatus || '';
  return (ord.paymentMethod || '').toLowerCase() !== 'cod' && paymentStatus === 'rejected';
}

function isAwaitingPaymentCheck(ord) {
  const paymentStatus = ord.paymentStatus || ord.paymentVerificationStatus || '';
  return (ord.paymentMethod || '').toLowerCase() !== 'cod' && paymentStatus === 'pending_verification';
}

export function initOrdersModule() {
  const ordersRef = query(ref(db, 'transactions'), orderByChild('createdAt'), limitToLast(500));

  onValue(ordersRef, (snapshot) => {
    globalOrdersCache = snapshot.val() || {};
    renderOrdersTable();
    window.hideLoading('orders');
    autoCompleteShippedOrders();

    // Keep an open Order Details popup in sync (e.g. right after a payment decision).
    if (openOrderId && globalOrdersCache[openOrderId]) {
      window.viewOrderDetailsModule(openOrderId);
    }
  });

  // Attach Search & Status Filter listeners
  document.getElementById('o-search-input')?.addEventListener('input', renderOrdersTable);
  document.getElementById('o-filter-status')?.addEventListener('change', renderOrdersTable);
}

// There are no Cloud Functions, so shipped orders that nobody confirmed are
// completed here, while the dashboard is open (the customer's app does the
// same check when the customer opens their orders).
// An order is due when its estimated delivery date was more than
// settings/autoCompleteDays days ago (3 when the setting is empty).
const DEFAULT_AUTO_COMPLETE_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;
const autoCompleteTried = new Set();

async function autoCompleteShippedOrders() {
  const due = Object.entries(globalOrdersCache).filter(([id, ord]) =>
    ord && String(ord.status || '').toLowerCase() === 'shipping' &&
    Number(ord.estimatedDelivery) > 0 && !autoCompleteTried.has(id));
  if (due.length === 0) return;

  let days = DEFAULT_AUTO_COMPLETE_DAYS;
  try {
    const value = (await get(ref(db, 'settings/autoCompleteDays'))).val();
    if (Number.isInteger(value) && value >= 0) days = value;
  } catch (err) {
    console.error('Could not read the auto-complete setting:', err);
  }

  const now = Date.now();
  for (const [id, ord] of due) {
    if (now <= Number(ord.estimatedDelivery) + days * DAY_MS) continue;
    autoCompleteTried.add(id); // one attempt per page load, even if it fails
    await processOrderStatusChange(id, 'Completed', null, true, 0, '', '', 0, 0, null,
      { completedAt: now, completedBy: 'auto' });
  }
}

function renderOrdersTable() {
  const tbody = document.getElementById('orders-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('o-search-input')?.value || '').toLowerCase();
  const selectedStatus = document.getElementById('o-filter-status')?.value || 'ALL';

  let orderEntries = Array.isArray(globalOrdersCache)
    ? globalOrdersCache.map((ord, index) => [index, ord]).filter(([_, ord]) => ord !== null)
    : Object.entries(globalOrdersCache);

  orderEntries = newestFirst(orderEntries); // newest orders at the top

  let filtered = orderEntries.filter(([id, ord]) => {
    if (!ord) return false;
    const recipient = (ord.recipientName || '').toLowerCase();
    const orderIdStr = String(id).toLowerCase();
    const status = ord.status || 'Pending';

    const matchesSearch = recipient.includes(searchQuery) || orderIdStr.includes(searchQuery);
    const matchesStatus = selectedStatus === 'ALL' || status === selectedStatus;
    return matchesSearch && matchesStatus;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:#64748b;">No matching customer orders found.</td></tr>';
    updateBulkActionsUI();
    return;
  }

  // Refunds and returns are for admins only.
  const isStaff = document.body.classList.contains('role-staff');

  const isAllSelected = filtered.length > 0 && filtered.every(([id]) => selectedOrderIds.has(id));

  filtered.forEach(([id, ord]) => {
    const recipient = ord.recipientName || 'N/A';
    
    let rawTotal = ord.grandTotal ?? 0;
    if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
    const total = parseFloat(rawTotal) || 0;

    const payment = ord.paymentMethod || 'COD';
    const status = ord.status || 'Pending';
    const badgeClass = status.toLowerCase().replace(/\s+/g, '-');
    const needsVerification = isAwaitingPaymentCheck(ord) && status === 'Pending';
    const paymentRejected = isPaymentRejected(ord);
    const isSelected = selectedOrderIds.has(id);

    // The database cannot add up the items, so warn when they do not match the subtotal.
    const rawItems = ord.items || [];
    const itemList = Array.isArray(rawItems) ? rawItems : Object.values(rawItems);
    const itemsSum = itemList.reduce(
      (sum, it) => sum + (parseFloat(it?.price) || 0) * (parseInt(it?.quantity, 10) || 0), 0);
    const subtotalValue = parseFloat(ord.subtotal);
    const totalsMismatch = Number.isFinite(subtotalValue) && Math.abs(itemsSum - subtotalValue) > 0.01;

    tbody.innerHTML += `
      <tr class="clickable-row">
        <td style="width:40px; padding:8px 4px;" onclick="event.stopPropagation();">
          <input type="checkbox" value="${escapeHtml(id)}" ${isSelected ? 'checked' : ''} onchange="window.toggleOrderSelection('${escapeHtml(id)}', this.checked)">
        </td>
        <td style="color:#2563eb; font-size:12px; font-weight:600;" onclick="window.viewOrderDetailsModule(${jsArg(id)})">#${escapeHtml(String(id).substring(0, 8))}</td>
        <td style="font-weight:600;" onclick="window.viewOrderDetailsModule(${jsArg(id)})">${escapeHtml(recipient)}</td>
        <td style="font-weight:bold;" onclick="window.viewOrderDetailsModule(${jsArg(id)})">₱${total.toFixed(2)}${totalsMismatch ? ' <span title="The items do not add up to the subtotal. Check this order before approving." style="color:#dc2626;">⚠</span>' : ''}</td>
        <td onclick="window.viewOrderDetailsModule(${jsArg(id)})">${escapeHtml(payment)}</td>
        <td onclick="window.viewOrderDetailsModule(${jsArg(id)})"><span class="badge badge-${badgeClass}">${escapeHtml(status)}</span>${status === 'Cancelled' && (ord.cancellationReason || ord.cancelledBy) ? `<div style="font-size:11px; color:#64748b; margin-top:4px; max-width:220px;">${ord.cancelledBy === 'customer' ? 'By customer' : ord.cancelledBy === 'admin' ? 'By store' : 'Cancelled'}${ord.cancellationReason ? ': ' + escapeHtml(ord.cancellationReason) : ''}</div>` : ''}</td>
        <td onclick="event.stopPropagation();">
          ${needsVerification
            ? `<button class="btn btn-primary" style="padding:6px 12px; font-size:13px;" onclick="window.viewOrderDetailsModule(${jsArg(id)})" aria-label="Verify payment for order ${escapeHtml(id)}">Verify payment</button>`
            : `<select onchange="window.updateOrderStatusModule('${escapeHtml(id)}', this.value)" style="padding:6px 10px; font-size:13px; border-radius:6px; border:1px solid #cbd5e1;" aria-label="Order ${escapeHtml(id)} status">
            ${status === 'Payment Rejected' ? '<option value="Payment Rejected" selected disabled>Payment Rejected</option>' : ''}
            ${paymentRejected && status !== 'Cancelled' ? '' : `
            <option value="Pending" ${status === 'Pending' ? 'selected' : ''}>Pending</option>
            <option value="Processing" ${status === 'Processing' ? 'selected' : ''}>Processing</option>
            <option value="Shipping" ${status === 'Shipping' ? 'selected' : ''}>Shipping</option>
            <option value="Completed" ${status === 'Completed' ? 'selected' : ''}>Completed</option>`}
            <option value="Cancelled" ${status === 'Cancelled' ? 'selected' : ''}>Cancelled</option>
            ${isStaff ? '' : `<option value="Returned" ${status === 'Returned' ? 'selected' : ''}>Returned</option>`}
          </select>`}
        </td>
      </tr>
    `;
  });
  updateBulkActionsUI();
}

// Toggle bulk actions bar visibility based on selection count.
function updateBulkActionsUI() {
  const bar = document.getElementById('bulk-order-actions');
  const countEl = document.getElementById('bulk-selected-count');
  const selectAll = document.getElementById('bulk-select-all');
  if (!bar || !countEl) return;

  const count = selectedOrderIds.size;
  countEl.innerText = count + ' selected';
  if (count > 0) {
    bar.style.display = 'flex';
  } else {
    bar.style.display = 'none';
  }

  if (selectAll) {
    const allRows = document.querySelectorAll('#orders-table-body input[type="checkbox"]');
    if (allRows.length > 0 && allRows.length === selectedOrderIds.size) {
      selectAll.checked = true;
    } else {
      selectAll.checked = false;
    }
  }
}

window.toggleOrderSelection = function(orderId, checked) {
  if (checked) {
    selectedOrderIds.add(orderId);
  } else {
    selectedOrderIds.delete(orderId);
  }
  updateBulkActionsUI();
};

window.toggleBulkSelectAll = function() {
  const selectAll = document.getElementById('bulk-select-all');
  const checked = selectAll.checked;
  // Get all visible order IDs from rendered rows
  const checkboxes = document.querySelectorAll('#orders-table-body input[type="checkbox"]');
  checkboxes.forEach((cb) => {
    cb.checked = checked;
    if (checked) selectedOrderIds.add(cb.value);
    else selectedOrderIds.delete(cb.value);
  });
  updateBulkActionsUI();
};

window.clearBulkSelection = function() {
  selectedOrderIds.clear();
  const checkboxes = document.querySelectorAll('#orders-table-body input[type="checkbox"]');
  checkboxes.forEach((cb) => cb.checked = false);
  const selectAll = document.getElementById('bulk-select-all');
  if (selectAll) selectAll.checked = false;
  updateBulkActionsUI();
};

window.bulkUpdateOrderStatus = async function() {
  if (selectedOrderIds.size === 0) {
    notify('Please select at least one order.');
    return;
  }

  const select = document.getElementById('bulk-status-select');
  const newStatus = select.value;
  if (!newStatus) return;

  if (!confirm(`Apply "${newStatus}" to ${selectedOrderIds.size} selected order(s)?`)) return;

  let success = 0;
  let failed = 0;

  for (const orderId of selectedOrderIds) {
    try {
      const ok = await window.updateOrderStatusModule(orderId, newStatus);
      if (ok) success++;
      else failed++;
    } catch (err) {
      failed++;
      console.error(`Bulk update failed for ${orderId}:`, err);
    }
  }

  notify(`Bulk update complete: ${success} succeeded, ${failed} failed.`);
  selectedOrderIds.clear();
  updateBulkActionsUI();
};

// Automated Order Status Update Interceptor
window.updateOrderStatusModule = async function(orderId, newStatus) {
  // Validate state transition before proceeding
  const ord = globalOrdersCache[orderId];
  if (ord) {
    const currentStatus = (ord.status || 'Pending').toLowerCase();
    const targetStatus = newStatus.toLowerCase();
    
    const validTransitions = {
      'pending': ['processing', 'cancelled'],
      'processing': ['shipping', 'cancelled'],
      'shipping': ['completed', 'cancelled'],
      'completed': ['returned'],
      'payment rejected': [], // final state
      'cancelled': [] // final state
    };
    
    const allowed = validTransitions[currentStatus] || [];
    if (!allowed.includes(targetStatus)) {
      notify(`Invalid status change: cannot move from "${currentStatus}" to "${newStatus}".`);
      return;
    }
  }

  if (newStatus === 'Cancelled') {
    pendingCancelOrderId = orderId;
    const cancelModal = document.getElementById('cancel-modal');
    if (cancelModal) {
      document.getElementById('cancel-reason-select').value = '';
      document.getElementById('cancel-reason-input').value = '';
      window.onCancelReasonChange();
      cancelModal.classList.add('active');
    }
    return;
  }

  if (newStatus === 'Returned') {
    // Returns go through the review window (reason, photo, refund account,
    // approve / reject) instead of a bare status change.
    renderOrdersTable(); // reset the dropdown back to the order's real status
    window.openReturnReview?.(orderId);
    return;
  }

  if (newStatus === 'Shipping') {
    pendingShipOrderId = orderId;
    const shipModal = document.getElementById('ship-modal');
    if (shipModal) {
      document.getElementById('ship-carrier-select').value = '';
      document.getElementById('ship-carrier-input').value = '';
      window.onShipCarrierChange();
      document.getElementById('ship-tracking-input').value = '';
      document.getElementById('ship-estimated-delivery-input').value = '';
      shipModal.classList.add('active');
    }
    return;
  }

  await processOrderStatusChange(orderId, newStatus, null);
};

// Custom Cancellation Modal Controls
window.closeCancelModal = function() {
  const cancelModal = document.getElementById('cancel-modal');
  if (cancelModal) cancelModal.classList.remove('active');
  pendingCancelOrderId = null;
  renderOrdersTable(); // Reset dropdown view visually if canceled out
};

// Custom Shipping Modal Controls
window.closeShipModal = function() {
  const shipModal = document.getElementById('ship-modal');
  if (shipModal) shipModal.classList.remove('active');
  pendingShipOrderId = null;
};

// Shows the courier name box only when "Other" is picked.
window.onShipCarrierChange = function() {
  const isOther = document.getElementById('ship-carrier-select').value === 'Other';
  const input = document.getElementById('ship-carrier-input');
  input.style.display = isOther ? '' : 'none';
  input.required = isOther;
  if (isOther) input.focus();
};

window.submitOrderShipping = async function(event) {
  event.preventDefault();
  if (!pendingShipOrderId) return;

  const carrierChoice = document.getElementById('ship-carrier-select').value;
  const carrierInput = carrierChoice === 'Other'
    ? document.getElementById('ship-carrier-input').value.trim()
    : carrierChoice;
  if (!carrierInput) { notify('Please choose a courier, or type its name under Other.'); return; }
  const trackingInput = document.getElementById('ship-tracking-input').value.trim();
  const estInput = document.getElementById('ship-estimated-delivery-input').value.trim();
  const orderId = pendingShipOrderId;

  const shippingCarrier = carrierInput;
  const trackingNumber = trackingInput;
  const shippedAt = Date.now();
  const estimatedDelivery = estInput ? new Date(estInput).getTime() : 0;

  window.closeShipModal();
  await processOrderStatusChange(orderId, 'Shipping', null, true, 0, shippingCarrier, trackingNumber, shippedAt, estimatedDelivery);
};

// "Open Return Review" button inside the order details window.
window.openReturnReviewFromOrder = function() {
  if (!openOrderId) return;
  const id = openOrderId;
  window.closeOrderModal?.();
  window.openReturnReview?.(id);
};

window.saveOrderAdminNotes = async function() {
  const orderId = openOrderId;
  const textarea = document.getElementById('modal-admin-notes');
  if (!orderId || !textarea) return;

  const notes = textarea.value.trim();

  try {
    const orderRef = ref(db, `transactions/${orderId}`);
    await update(orderRef, { adminNotes: notes });
    notify('Admin notes saved.');
  } catch (err) {
    console.error('Could not save admin notes:', err);
    notify('Failed to save notes. Please check your network connection.');
  }
};

// Shows the text box only when "Other" is picked.
window.onCancelReasonChange = function() {
  const isOther = document.getElementById('cancel-reason-select').value === 'Other';
  document.getElementById('cancel-reason-other-group').style.display = isOther ? '' : 'none';
};

window.submitOrderCancellation = async function(event) {
  event.preventDefault();
  if (!pendingCancelOrderId) return;

  const choice = document.getElementById('cancel-reason-select').value;
  const other = document.getElementById('cancel-reason-input').value.trim();
  if (!choice) { notify('Please select a reason.'); return; }
  if (choice === 'Other' && !other) { notify('Please type the reason.'); return; }
  const reasonInput = choice === 'Other' ? `Other: ${other}` : choice;
  const orderId = pendingCancelOrderId;

  window.closeCancelModal();
  await processOrderStatusChange(orderId, 'Cancelled', reasonInput);
};

// Core Status & Inventory Synchronization Processor
// [shouldNotify] is false when the caller sends its own notification (payment approval, return review).
// [refundAmount] is the admin-approved refund for a Returned order.
// [shippingCarrier], [trackingNumber], [shippedAt], [estimatedDelivery] are set when moving to Shipping.
// [extraFields] are extra values saved with the status change (completedAt / completedBy on auto-complete).
// [returnOptions] = { restock: boolean, fields: {...} } when approving a return: restock puts the
// items back in stock, fields are extra values saved on the order (returnStatus, refund account...).
export async function processOrderStatusChange(orderId, newStatus, cancellationReason, shouldNotify = true, refundAmount = 0, shippingCarrier = '', trackingNumber = '', shippedAt = 0, estimatedDelivery = 0, returnOptions = null, extraFields = null) {
  const orderRef = ref(db, `transactions/${orderId}`);

  try {
    const snapshot = await get(orderRef);
    if (!snapshot.exists()) return false;
    const ord = snapshot.val();

    const isDeducted = ord.stockDeducted || false;
    const activeStatuses = ['processing', 'shipping', 'completed'];
    const targetStatusLower = newStatus.toLowerCase();

    // Deduct inventory when order moves to Processing/Shipping/Completed (if not previously deducted)
    if (activeStatuses.includes(targetStatusLower) && !isDeducted) {
      await adjustInventoryForOrder(ord, 'deduct');
      const shippingUpdate = targetStatusLower === 'shipping'
        ? { shippingCarrier, trackingNumber, shippedAt: shippedAt || Date.now(), estimatedDelivery }
        : {};
      await update(orderRef, { status: newStatus, stockDeducted: true, cancellationReason: null, cancelledBy: null, ...shippingUpdate, ...(extraFields || {}) });
    } 
// Restore inventory if an active order is changed to Cancelled
    else if (targetStatusLower === 'cancelled' && isDeducted) {
      await adjustInventoryForOrder(ord, 'restore');
      await update(orderRef, { status: newStatus, stockDeducted: false, cancellationReason: cancellationReason, cancelledBy: 'admin' });
    } 
    // Handle order return: optionally restore inventory, mark as returned, set refund info.
    // Works whether or not stock was deducted, so the refund fields are always saved.
    else if (targetStatusLower === 'returned') {
      if (String(ord.status || '').toLowerCase() !== 'completed') {
        const notCompleted = new Error('Only completed orders can be returned.');
        notCompleted.userMessage = 'Only completed orders can be returned.';
        throw notCompleted;
      }
      const restock = returnOptions?.restock !== false;
      const restored = isDeducted && restock;
      if (restored) await adjustInventoryForOrder(ord, 'restore');
      await update(orderRef, {
        status: newStatus,
        ...(restored ? { stockDeducted: false } : {}),
        returnReason: cancellationReason,
        refundAmount: refundAmount,
        refundStatus: 'refund_pending',
        returnRestocked: restored,
        ...(returnOptions?.fields || {}),
      });
    }
    // Regular status update
    else {
      const shippingUpdate = targetStatusLower === 'shipping'
        ? { shippingCarrier, trackingNumber, shippedAt: shippedAt || Date.now(), estimatedDelivery }
        : {};
      await update(orderRef, { status: newStatus, cancellationReason: targetStatusLower === 'cancelled' ? cancellationReason : null, cancelledBy: targetStatusLower === 'cancelled' ? 'admin' : null, ...shippingUpdate, ...(extraFields || {}) });
    }

    // Mark purchased products so the customer is eligible to leave a review
    // Written whenever an order reaches Completed, regardless of when stock was deducted.
    if (targetStatusLower === 'completed') {
      const purchasedUpdates = {};
      const items = orderedItems(ord);
      const uid = ord.userId;
      if (uid) {
        items.forEach((item) => {
          purchasedUpdates[`purchasedProducts/${item.productId}/${uid}`] = true;
        });
      }
      if (Object.keys(purchasedUpdates).length > 0) {
        await update(ref(db), purchasedUpdates);
      }
    }

    if (shouldNotify && String(ord.status || '').toLowerCase() !== targetStatusLower) {
      if (targetStatusLower === 'shipping') {
        await notifyOrderShipped(orderId, ord, trackingNumber, shippingCarrier);
      } else {
        await notifyOrderStatus(orderId, ord, newStatus, cancellationReason);
      }
    }
    return true;
  } catch (error) {
    if (error instanceof InsufficientStockError) {
      notify(
        `Cannot move this order forward: only ${error.available} of "${error.productName}" ` +
        `in stock, but the order needs ${error.needed}. Update the stock or cancel the order.`
      );
      return false;
    }
    console.error("Error updating order status and adjusting inventory:", error);
    notify(error?.userMessage || "Failed to update order status. Please check your network connection.");
    return false;
  }
}

// Raised before any stock is changed, when an order needs more than is left.
class InsufficientStockError extends Error {
  constructor(productName, needed, available) {
    super(`Not enough stock for ${productName}`);
    this.productName = productName;
    this.needed = needed;
    this.available = available;
  }
}

function orderedItems(ord) {
  const raw = ord.items || [];
  const list = Array.isArray(raw) ? raw : Object.values(raw);
  return list.filter((item) => item && item.productId);
}

// Deducts or restores productStock for every item of an order.
  // The app never changes stock, so this is the only place it happens.
  // For 'deduct', the check-and-deduct is done atomically in a transaction
  // to prevent race conditions when multiple admins process orders concurrently.
  async function adjustInventoryForOrder(ord, action) {
    const items = orderedItems(ord);

    if (action === 'deduct') {
      // Deduct atomically per item; roll back any already-deducted items if a
      // later item fails so the order never leaves partial stock changes.
      const deducted = [];
      for (const item of items) {
        const stockRef = ref(db, `products/${item.productId}/productStock`);
        const qty = parseInt(item.quantity || 1, 10);
        const productName = item.productName || item.productId;

        const result = await runTransaction(stockRef, (current) => {
          // Firebase may call with null initially — return unchanged to retry with real value
          if (current === null) return current;
          const stock = parseInt(current, 10) || 0;
          if (stock < qty) {
            return undefined; // abort transaction — insufficient stock
          }
          return stock - qty;
        });

        if (!result.committed) {
          // Roll back every item already deducted for this order
          for (const rolled of deducted) {
            try {
              await runTransaction(ref(db, `products/${rolled.productId}/productStock`), (current) => {
                if (current === null) return current;
                return (parseInt(current, 10) || 0) + rolled.qty;
              });
            } catch (rollbackErr) {
              console.error('Stock rollback failed for', rolled.productId, rollbackErr);
            }
          }
          const snap = await get(stockRef);
          const available = snap.exists() ? parseInt(snap.val(), 10) || 0 : 0;
          throw new InsufficientStockError(productName, qty, available);
        }
        deducted.push({ productId: item.productId, qty });
      }
    } else if (action === 'restore') {
      // Restore: simple additive transaction
      for (const item of items) {
        const stockRef = ref(db, `products/${item.productId}/productStock`);
        const qty = parseInt(item.quantity || 1, 10);

        await runTransaction(stockRef, (current) => {
          if (current === null) return current;
          return (parseInt(current, 10) || 0) + qty;
        });
      }
    }
  }

// CSV Export Handler
window.exportOrdersToCSV = function() {
  if (!globalOrdersCache || Object.keys(globalOrdersCache).length === 0) {
    notify("No transactions available to export.");
    return;
  }

  let csvContent = "data:text/csv;charset=utf-8,Order ID,Recipient Name,Total Amount (PHP),Payment Method,Status\n";

  // CSV formula injection guard: prefix ' for fields starting with = + - @ or tab
  const csvSafe = (val) => {
    const s = String(val);
    return /^[=+\-@\t]/.test(s) ? `'${s}` : s;
  };

  Object.entries(globalOrdersCache).forEach(([id, ord]) => {
    if (!ord) return;
    const recipient = `"${(ord.recipientName || 'N/A').replace(/"/g, '""')}"`;
    let rawTotal = ord.grandTotal ?? 0;
    if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
    const total = parseFloat(rawTotal) || 0;
    const payment = ord.paymentMethod || 'COD';
    const status = ord.status || 'Pending';

    csvContent += `${csvSafe(id)},${csvSafe(recipient)},${csvSafe(total.toFixed(2))},${csvSafe(payment)},${csvSafe(status)}\n`;
  });

  const encodedUri = encodeURI(csvContent);
  const link = document.createElement("a");
  link.setAttribute("href", encodedUri);
  link.setAttribute("download", `pc_parts_orders_${new Date().toISOString().slice(0, 10)}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
};

// Modal Detail View with Cancellation Notice Display
window.viewOrderDetailsModule = function(orderId) {
  const ord = globalOrdersCache[orderId];
  if (!ord) return;
  openOrderId = orderId;

  document.getElementById('modal-order-id').innerText = `(#${orderId})`;
  document.getElementById('modal-customer-name').innerText = ord.recipientName || 'N/A';
  document.getElementById('modal-customer-contact').innerText = ord.phoneNumber || ord.email || ord.userEmail || 'N/A';
  document.getElementById('modal-customer-address').innerText = ord.deliveryAddress || 'N/A';

  // Map pin chosen by the customer (optional): show an OpenStreetMap link next to the address
  const addressEl = document.getElementById('modal-customer-address');
  const oldPinLink = document.getElementById('modal-customer-pin');
  if (oldPinLink) oldPinLink.remove();
  const lat = Number(ord.deliveryLat);
  const lng = Number(ord.deliveryLng);
  if (ord.deliveryLat != null && ord.deliveryLng != null && Number.isFinite(lat) && Number.isFinite(lng)) {
    const link = document.createElement('a');
    link.id = 'modal-customer-pin';
    link.href = `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=18/${lat}/${lng}`;
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    link.innerText = ' 📍 View pin on map';
    addressEl.insertAdjacentElement('afterend', link);
  }
  document.getElementById('modal-payment-method').innerText = ord.paymentMethod || 'COD';
  window.renderOrderPaymentReview?.(orderId, ord);

  // Handle Cancellation Reason Display
  const cancellationCard = document.getElementById('modal-cancellation-card');
  const cancellationReasonText = document.getElementById('modal-cancellation-reason');
  
  if (ord.status === 'Cancelled' && (ord.cancellationReason || ord.cancelledBy)) {
    cancellationReasonText.innerText = ord.cancellationReason || 'No reason recorded.';
    const byText = document.getElementById('modal-cancelled-by');
    if (byText) {
      byText.innerText = ord.cancelledBy === 'customer' ? 'Customer'
        : ord.cancelledBy === 'admin' ? 'Store (admin)' : 'Not recorded';
    }
    const priorRow = document.getElementById('modal-prior-rejection-row');
    const priorText = document.getElementById('modal-prior-rejection');
    if (priorRow && priorText) {
      priorText.innerText = ord.paymentRejectionReason || '';
      priorRow.style.display = ord.paymentRejectionReason ? '' : 'none';
    }
    if (cancellationCard) cancellationCard.style.display = 'block';
  } else {
    if (cancellationCard) cancellationCard.style.display = 'none';
  }

  // Handle Return Info Display (full review happens in the Returns window)
  const returnCard = document.getElementById('modal-return-card');
  const hasReturn = ord.status === 'Returned' || !!ord.returnReason;

  if (hasReturn && returnCard) {
    const rs = ord.refundStatus === 'refunded' ? 'Refunded'
      : ord.refundStatus === 'refund_pending' ? 'Approved - refund to send'
      : ord.returnStatus === 'rejected' ? 'Declined'
      : ord.status === 'Returned' ? 'Approved - refund to send'
      : 'Waiting for review';
    const refundAmt = ord.refundAmount ? parseFloat(ord.refundAmount).toFixed(2) : '0.00';
    const setText = (id, text) => { const el = document.getElementById(id); if (el) el.innerText = text; };
    setText('modal-return-status', rs);
    setText('modal-return-reason', ord.returnReason || 'N/A');
    setText('modal-return-refund', ord.returnStatus === 'rejected' ? 'None' : `₱${refundAmt}${ord.refundStatus ? ` (${ord.refundStatus})` : ''}`);
    setText('modal-return-destination', ord.refundMethod
      ? `${ord.refundMethod} - ${ord.refundAccountName || ''} ${ord.refundAccountNumber || ''}`.trim()
      : 'Not provided');
    returnCard.style.display = 'block';

    const returnImageEl = document.getElementById('modal-return-image');
    if (returnImageEl) {
      if (typeof ord.returnImageUrl === 'string' && ord.returnImageUrl.startsWith('data:image/')) {
        returnImageEl.style.display = 'block';
        returnImageEl.innerHTML = `<img src="${escapeHtml(ord.returnImageUrl)}" alt="Return proof" style="max-width:200px;max-height:200px;border:1px solid #cbd5e1;border-radius:8px;">`;
      } else {
        returnImageEl.style.display = 'none';
        returnImageEl.innerHTML = '';
      }
    }
  } else if (returnCard) {
    returnCard.style.display = 'none';
  }

  // Handle Shipping Info Display
  const shipCard = document.getElementById('modal-shipping-card');
  const shipCarrierText = document.getElementById('modal-shipping-carrier');
  const shipTrackingText = document.getElementById('modal-shipping-tracking');
  const shipDateText = document.getElementById('modal-shipping-date');
  const shipEstText = document.getElementById('modal-shipping-est');

  if (ord.trackingNumber || ord.shippingCarrier || ord.status === 'Shipping') {
    if (shipCarrierText && ord.shippingCarrier) shipCarrierText.innerText = ord.shippingCarrier;
    if (shipTrackingText && ord.trackingNumber) shipTrackingText.innerText = ord.trackingNumber;
    if (shipDateText && ord.shippedAt) shipDateText.innerText = new Date(ord.shippedAt).toLocaleDateString();
    if (shipEstText && ord.estimatedDelivery) shipEstText.innerText = new Date(ord.estimatedDelivery).toLocaleDateString();
    if (shipCard) shipCard.style.display = 'block';
  } else {
    if (shipCard) shipCard.style.display = 'none';
  }

  // Handle Admin Notes Display
  const adminNotesCard = document.getElementById('modal-admin-notes-card');
  const adminNotesTextarea = document.getElementById('modal-admin-notes');

  if (adminNotesCard && adminNotesTextarea) {
    adminNotesTextarea.value = ord.adminNotes || '';
    adminNotesCard.style.display = 'block';
  }

const itemsList = ord.items || [];
  const itemsTbody = document.getElementById('modal-items-tbody');
  itemsTbody.innerHTML = '';

  let calculatedGrandTotal = 0;

  const fragment = document.createDocumentFragment();

  if (Array.isArray(itemsList) && itemsList.length > 0) {
    itemsList.forEach((item) => {
      const itemName = item.productName || 'Unknown Item';
      let rawPrice = item.price ?? 0;
      if (typeof rawPrice === 'string') rawPrice = rawPrice.replace(/[^0-9.-]+/g, "");
      const price = parseFloat(rawPrice) || 0;
      const qty = parseInt(item.quantity || 1, 10);
      const subtotal = price * qty;
      calculatedGrandTotal += subtotal;

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td style="font-weight:600; color:#1e293b;">${escapeHtml(itemName)}</td>
        <td>₱${price.toFixed(2)}</td>
        <td>${qty}</td>
        <td style="font-weight:600;">₱${subtotal.toFixed(2)}</td>
      `;
      fragment.appendChild(tr);
    });
  } else {
    const tr = document.createElement('tr');
    tr.innerHTML = '<td colspan="4" style="text-align:center; color:#64748b;">No item details available.</td>';
    fragment.appendChild(tr);
  }

  // --- NEW: DISPLAY PROMO CODE & DISCOUNT IF APPLICABLE ---
  if (ord.promoCode && ord.discount) {
    const discount = parseFloat(ord.discount) || 0;
    if (discount > 0) {
      const tr = document.createElement('tr');
      tr.style.backgroundColor = '#f0fdf4';
      tr.innerHTML = `
        <td colspan="3" style="text-align:right; font-weight:600; color:#16a34a;">Promo Applied (${escapeHtml(ord.promoCode)}):</td>
        <td style="font-weight:bold; color:#16a34a;">-₱${discount.toFixed(2)}</td>
      `;
      fragment.appendChild(tr);
    }
  }
  // --------------------------------------------------------

  itemsTbody.appendChild(fragment);

  let rawTotal = ord.grandTotal ?? calculatedGrandTotal;
  if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
  const grandTotal = parseFloat(rawTotal) || calculatedGrandTotal;

  document.getElementById('modal-grand-total').innerText = `₱${grandTotal.toFixed(2)}`;
  document.getElementById('order-modal').classList.add('active');
};

window.closeOrderModal = function() {
  openOrderId = null;
  document.getElementById('order-modal').classList.remove('active');
};

window.addEventListener('click', (e) => {
  const modal = document.getElementById('order-modal');
  if (e.target === modal) window.closeOrderModal();

  const cancelModal = document.getElementById('cancel-modal');
  if (e.target === cancelModal) window.closeCancelModal();

  const shipModal = document.getElementById('ship-modal');
  if (e.target === shipModal) window.closeShipModal();
});

// Print a clean receipt for the currently open order modal.
window.printOrderReceipt = function() {
  const ord = globalOrdersCache[openOrderId];
  if (!ord) return;

  const items = ord.items || [];
  const shortId = String(orderId).substring(0, 8);
  const recipient = ord.recipientName || 'N/A';
  const phone = ord.phoneNumber || 'N/A';
  const address = ord.deliveryAddress || 'N/A';
  const status = ord.status || 'Pending';
  const payment = ord.paymentMethod || 'COD';
  const paymentStatus = ord.paymentStatus || 'pending_verification';
  const createdAt = ord.createdAt || 0;
  const dateStr = createdAt > 0 ? new Date(createdAt).toLocaleString() : 'N/A';

  let subtotal = 0;
  const itemRows = items.map((it) => {
    const qty = parseInt(it.quantity) || 0;
    const price = parseFloat(it.price) || 0;
    const line = price * qty;
    subtotal += line;
    const variant = it.variantSelection ? ` (${escapeHtml(it.variantSelection)})` : '';
    return `<tr>
      <td style="padding:6px;border-bottom:1px solid #e2e8f0;">${escapeHtml(it.productName || 'Product')}${variant}</td>
      <td style="padding:6px;border-bottom:1px solid #e2e8f0;text-align:right;">₱${price.toFixed(2)}</td>
      <td style="padding:6px;border-bottom:1px solid #e2e8f0;text-align:center;">${qty}</td>
      <td style="padding:6px;border-bottom:1px solid #e2e8f0;text-align:right;">₱${line.toFixed(2)}</td>
    </tr>`;
  }).join('');

  const discount = parseFloat(ord.discount) || 0;
  const shippingFee = parseFloat(ord.shippingFee) || 0;
  const grandTotal = parseFloat(ord.grandTotal) || 0;

  const refundInfo = ord.status === 'Returned'
    ? `<p><strong>Refund:</strong> ₱${(ord.refundAmount || 0).toFixed(2)} (${ord.refundStatus || 'refund_pending'})</p>`
    : '';

  const shippingInfo = ord.trackingNumber
    ? `<p><strong>Carrier:</strong> ${escapeHtml(ord.shippingCarrier || 'N/A')}<br><strong>Tracking:</strong> ${escapeHtml(ord.trackingNumber)}</p>`
    : '';

  const win = window.open('', '_blank');
  win.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Receipt #${shortId}</title>
      <style>
        @media print { body { -webkit-print-color-adjust: exact; } }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 13px; color: #1e293b; line-height: 1.4; padding: 24px; }
        .header { text-align: center; margin-bottom: 24px; border-bottom: 2px solid #1e293b; padding-bottom: 16px; }
        .header h1 { margin: 0; font-size: 20px; color: #1e293b; }
        .header p { margin: 4px 0 0; color: #64748b; font-size: 12px; }
        .info-grid { display: flex; gap: 24px; margin: 20px 0; }
        .info-col { flex: 1; }
        .info-col p { margin: 4px 0; font-size: 13px; }
        .info-col strong { color: #374151; }
        table { width: 100%; border-collapse: collapse; margin: 16px 0; }
        th { text-align: left; padding: 8px; font-size: 12px; color: #64748b; border-bottom: 2px solid #1e293b; }
        td { padding: 8px; font-size: 13px; border-bottom: 1px solid #e2e8f0; }
        .totals { margin-top: 16px; text-align: right; }
        .totals table { width: auto; margin-left: auto; }
        .totals td { border: none; padding: 4px 12px; }
        .totals .grand-total { font-weight: bold; font-size: 15px; color: #1e293b; border-top: 2px solid #1e293b; padding-top: 8px; }
        .notes { margin-top: 20px; font-size: 12px; color: #64748b; }
        .print-btn { display: none; }
        @media print { .print-btn { display: inline-block; margin-top: 16px; } }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>PC Parts Store</h1>
        <p>Order Receipt #${shortId}</p>
      </div>
      <div class="info-grid">
        <div class="info-col">
          <p><strong>Customer:</strong> ${escapeHtml(recipient)}</p>
          <p><strong>Phone:</strong> ${escapeHtml(phone)}</p>
          <p><strong>Address:</strong> ${escapeHtml(address)}</p>
        </div>
        <div class="info-col">
          <p><strong>Order Date:</strong> ${dateStr}</p>
          <p><strong>Status:</strong> ${escapeHtml(status)}</p>
          <p><strong>Payment:</strong> ${escapeHtml(payment)} (${escapeHtml(paymentStatus)})</p>
        </div>
      </div>
      <table>
        <thead>
          <tr>
            <th>Item</th>
            <th style="text-align:right;">Price</th>
            <th style="text-align:center;">Qty</th>
            <th style="text-align:right;">Total</th>
          </tr>
        </thead>
        <tbody>
          ${itemRows}
        </tbody>
      </table>
      <div class="totals">
        <table>
          <tr><td>Subtotal:</td><td style="text-align:right;">₱${subtotal.toFixed(2)}</td></tr>
          ${discount > 0 ? `<tr><td>Discount:</td><td style="text-align:right;">-₱${discount.toFixed(2)}</td></tr>` : ''}
          <tr><td>Shipping:</td><td style="text-align:right;">₱${shippingFee.toFixed(2)}</td></tr>
          <tr class="grand-total"><td>Total:</td><td style="text-align:right;">₱${grandTotal.toFixed(2)}</td></tr>
        </table>
      </div>
      ${shippingInfo}
      ${refundInfo}
      <div class="notes">
        <p>Thank you for your purchase! This receipt was generated from the admin dashboard.</p>
      </div>
      <button class="print-btn" onclick="window.print()">Print Receipt</button>
      <script>window.print();</script>
    </body>
    </html>
  `);
  win.document.close();
};