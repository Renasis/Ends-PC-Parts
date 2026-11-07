import { ref, onValue, query, limitToLast } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";

let rawUsersData = {};
let rawTransactionsData = {};

export function initCustomersModule() {
  const usersRef = query(ref(db, 'users'), limitToLast(500));
  const transactionsRef = query(ref(db, 'transactions'), limitToLast(500));

  onValue(usersRef, (snapshot) => {
    rawUsersData = snapshot.val() || {};
    renderCustomersView();
  });

  onValue(transactionsRef, (snapshot) => {
    rawTransactionsData = snapshot.val() || {};
    renderCustomersView();
    window.hideLoading('customers');
  });

  document.getElementById('cust-search-input')?.addEventListener('input', renderCustomersTable);
}

function getCustomerList() {
  if (!rawUsersData) return [];
  if (Array.isArray(rawUsersData)) {
    return rawUsersData
      .map((user, index) => [index, user])
      .filter(([_, user]) => user !== null && typeof user === 'object');
  }
  return Object.entries(rawUsersData)
    .filter(([_, user]) => user !== null && typeof user === 'object');
}

function renderCustomersView() {
  const customerEntries = getCustomerList();
  const transactions = Object.values(rawTransactionsData || {});

  let activeBuyersCount = 0;
  let totalSystemSpend = 0;

  customerEntries.forEach(([uid, user]) => {
    const userEmail = (user.email || '').toLowerCase();
    
    // Find all orders placed by this user
    const userOrders = transactions.filter((ord) => {
      if (!ord) return false;
      const oEmail = (ord.phoneNumber || ord.email || ord.userEmail || '').toLowerCase();
      return (ord.userId === uid) || (oEmail && oEmail === userEmail);
    });

    if (userOrders.length > 0) activeBuyersCount++;

    userOrders.forEach((ord) => {
      if (!['cancelled', 'payment rejected'].includes((ord.status || '').toLowerCase())) {
        let rawTotal = ord.grandTotal ?? 0;
        if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
        totalSystemSpend += parseFloat(rawTotal) || 0;
      }
    });
  });

  const totalUsers = customerEntries.length;
  const avgSpend = totalUsers > 0 ? totalSystemSpend / totalUsers : 0;

  const totalEl = document.getElementById('cust-stat-total');
  const buyersEl = document.getElementById('cust-stat-buyers');
  const avgEl = document.getElementById('cust-stat-avg');

  if (totalEl) totalEl.innerText = totalUsers;
  if (buyersEl) buyersEl.innerText = activeBuyersCount;
  if (avgEl) avgEl.innerText = `₱${avgSpend.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

  renderCustomersTable();
}

function renderCustomersTable() {
  const tbody = document.getElementById('customers-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('cust-search-input')?.value || '').toLowerCase();
  const customerEntries = getCustomerList();
  const transactions = Object.entries(rawTransactionsData || {});

  let filtered = customerEntries.filter(([_, user]) => {
    const name = (user.name || '').toLowerCase();
    const email = (user.email || '').toLowerCase();
    return name.includes(searchQuery) || email.includes(searchQuery);
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:#64748b;">No registered customers found.</td></tr>';
    return;
  }

  const fragment = document.createDocumentFragment();

  filtered.forEach(([uid, user]) => {
    const name = user.name || 'Anonymous User';
    const email = user.email || 'N/A';
    const phone = user.phoneNumber || 'N/A';

    // Aggregate user transactions
    const userOrders = transactions.filter(([_, ord]) => {
      if (!ord) return false;
      const oEmail = (ord.phoneNumber || ord.email || ord.userEmail || '').toLowerCase();
      return (ord.userId === uid) || (oEmail && oEmail === email.toLowerCase());
    });

    let completedCount = 0;
    let lifetimeSpend = 0;

    userOrders.forEach(([_, ord]) => {
      const status = (ord.status || '').toLowerCase();
      if (status !== 'cancelled' && status !== 'payment rejected') {
        let rawTotal = ord.grandTotal ?? 0;
        if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
        lifetimeSpend += parseFloat(rawTotal) || 0;
      }
      if (status === 'completed') {
        completedCount++;
      }
    });

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="font-weight:600; color:#1e293b;">${escapeHtml(name)}</td>
      <td>${escapeHtml(email)}</td>
      <td>${escapeHtml(phone)}</td>
      <td><span class="badge badge-processing">${completedCount} Completed</span></td>
      <td style="font-weight:600; color:#166534;">₱${lifetimeSpend.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
      <td style="font-size:13px;">${user.privacyAcceptedAt ? `<span style="color:#166534;">Accepted ${escapeHtml(new Date(user.privacyAcceptedAt).toLocaleDateString('en-PH'))}</span>` : '<span style="color:#92400e;">Not yet</span>'}</td>
      <td>
        <button class="btn btn-secondary" onclick="window.viewCustomerProfileModule(${jsArg(uid)}, ${jsArg(encodeURIComponent(JSON.stringify(user)))})">View History</button>
      </td>
    `;
    fragment.appendChild(tr);
  });

  tbody.appendChild(fragment);
}

// Open Customer Profile & History Modal
window.viewCustomerProfileModule = function(uid, encodedUser) {
  const user = JSON.parse(decodeURIComponent(encodedUser));

  const name = user.name || 'Anonymous User';
  const email = user.email || 'N/A';
  const phone = user.phoneNumber || 'N/A';
  const address = user.deliveryAddress || 'No primary address provided.';

  document.getElementById('c-modal-name').innerText = name;
  document.getElementById('c-modal-email').innerText = email;
  document.getElementById('c-modal-phone').innerText = phone;
  document.getElementById('c-modal-address').innerText = address;

  const modalTbody = document.getElementById('c-modal-orders-tbody');
  modalTbody.innerHTML = '';

  const transactions = Object.entries(rawTransactionsData || {});
  const userOrders = transactions.filter(([_, ord]) => {
    if (!ord) return false;
    const oEmail = (ord.phoneNumber || ord.email || ord.userEmail || '').toLowerCase();
    return (ord.userId === uid) || (oEmail && email && oEmail === email.toLowerCase());
  });

  if (userOrders.length === 0) {
    modalTbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color:#64748b;">No purchase history recorded for this customer.</td></tr>';
  } else {
    const fragment = document.createDocumentFragment();

    userOrders.forEach(([orderId, ord]) => {
      let rawTotal = ord.grandTotal ?? 0;
      if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
      const total = parseFloat(rawTotal) || 0;
      const payment = ord.paymentMethod || 'COD';
      const status = ord.status || 'Pending';

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td style="color:#2563eb; font-weight:600; font-size:12px;">#${escapeHtml(String(orderId).substring(0, 8))}</td>
        <td>${escapeHtml(payment)}</td>
        <td><span class="badge badge-${escapeHtml(status.toLowerCase().replace(/\s+/g, '-'))}">${escapeHtml(status)}</span></td>
        <td style="font-weight:600;">₱${total.toFixed(2)}</td>
      `;
      fragment.appendChild(tr);
    });

    modalTbody.appendChild(fragment);
  }

  document.getElementById('customer-modal').classList.add('active');
};

window.closeCustomerModal = function() {
  document.getElementById('customer-modal').classList.remove('active');
};

window.addEventListener('click', (e) => {
  const modal = document.getElementById('customer-modal');
  if (e.target === modal) window.closeCustomerModal();
});