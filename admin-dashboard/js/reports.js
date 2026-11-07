import { notify } from "./toast.js";
import { ref, onValue } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml } from "./html-utils.js";

let rawTransactionsCache = {};

export function initReportsModule() {
  const transactionsRef = ref(db, 'transactions');

  onValue(transactionsRef, (snapshot) => {
    rawTransactionsCache = snapshot.val() || {};
    renderReportsDashboard();
    window.hideLoading('reports');
  });
}

function getTransactionsList() {
  if (!rawTransactionsCache) return [];
  if (Array.isArray(rawTransactionsCache)) {
    return rawTransactionsCache
      .map((ord, idx) => [idx, ord])
      .filter(([_, ord]) => ord !== null && typeof ord === 'object');
  }
  return Object.entries(rawTransactionsCache)
    .filter(([_, ord]) => ord !== null && typeof ord === 'object');
}

window.applyDateFilterReport = function() {
  renderReportsDashboard();
};

window.resetDateFilterReport = function() {
  const startInput = document.getElementById('report-start-date');
  const endInput = document.getElementById('report-end-date');
  if (startInput) startInput.value = '';
  if (endInput) endInput.value = '';
  renderReportsDashboard();
};

function renderReportsDashboard() {
  const tbody = document.getElementById('reports-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const startDateStr = document.getElementById('report-start-date')?.value;
  const endDateStr = document.getElementById('report-end-date')?.value;

  const startTime = startDateStr ? new Date(startDateStr).getTime() : 0;
  const endTime = endDateStr ? new Date(endDateStr).getTime() + 86400000 - 1 : Number.MAX_SAFE_INTEGER;

  const entries = getTransactionsList();
  let filteredList = [];
  let totalRevenue = 0;
  let completedCount = 0;

  entries.forEach(([id, ord]) => {
    if (!ord) return;
    const timestamp = ord.timestamp || ord.createdAt || 0;

    if (timestamp > 0 && (timestamp < startTime || timestamp > endTime)) {
      return;
    }

    filteredList.push({ id, ...ord });

    const status = (ord.status || '').toLowerCase();
    if (status !== 'cancelled' && status !== 'payment rejected') {
      let rawTotal = ord.grandTotal ?? 0;
      if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
      const total = parseFloat(rawTotal) || 0;
      totalRevenue += total;
    }

    if (status === 'completed') {
      completedCount++;
    }
  });

  const revEl = document.getElementById('report-stat-revenue');
  const ordEl = document.getElementById('report-stat-orders');
  const compEl = document.getElementById('report-stat-completed');

  if (revEl) revEl.innerText = `₱${totalRevenue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  if (ordEl) ordEl.innerText = filteredList.length;
  if (compEl) compEl.innerText = completedCount;

  if (filteredList.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:#64748b;">No transactions found within the selected date range.</td></tr>';
    return;
  }

  filteredList.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));

  const fragment = document.createDocumentFragment();

  filteredList.forEach((ord) => {
    const customer = ord.recipientName || 'N/A';
    const payment = (ord.paymentMethod || ord.payment || 'COD').toUpperCase();
    const status = ord.status || 'Pending';
    
    let rawTotal = ord.grandTotal ?? 0;
    if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
    const total = parseFloat(rawTotal) || 0;

    const dateStr = ord.timestamp ? new Date(ord.timestamp).toLocaleDateString() : 'N/A';

    let badgeClass = 'badge-processing';
    if (status === 'Completed') badgeClass = 'badge-completed';
    else if (status === 'Cancelled' || status === 'Payment Rejected') badgeClass = 'badge-cancelled';
    else if (status === 'Pending') badgeClass = 'badge-pending';
    else if (status === 'Returned') badgeClass = 'badge-returned';

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="font-weight:600; color:#2563eb;">#${escapeHtml(String(ord.id).substring(0, 8))}</td>
      <td>${escapeHtml(dateStr)}</td>
      <td>${escapeHtml(customer)}</td>
      <td>${escapeHtml(payment)}</td>
      <td><span class="badge ${badgeClass}">${escapeHtml(status)}</span></td>
      <td style="font-weight:600; color:#166534;">₱${total.toFixed(2)}</td>
    `;
    fragment.appendChild(tr);
  });

  tbody.appendChild(fragment);
}

window.exportReportToCSV = function() {
  const startDateStr = document.getElementById('report-start-date')?.value || 'All Time';
  const endDateStr = document.getElementById('report-end-date')?.value || 'Present';
  
  const entries = getTransactionsList();
  if (entries.length === 0) {
    notify("No data available to export.");
    return;
  }

  let csvContent = "data:text/csv;charset=utf-8,Order ID,Date,Recipient,Payment Method,Status,Total Amount\n";

  entries.forEach(([id, ord]) => {
    if (!ord) return;
    const dateStr = ord.timestamp ? new Date(ord.timestamp).toISOString().split('T')[0] : 'N/A';
    const customer = `"${((ord.recipientName || 'N/A').replace(/"/g, '""'))}"`;
    const payment = (ord.paymentMethod || ord.payment || 'COD').toUpperCase();
    const status = ord.status || 'Pending';
    let rawTotal = ord.grandTotal ?? 0;
    if (typeof rawTotal === 'string') rawTotal = rawTotal.replace(/[^0-9.-]+/g, "");
    const total = parseFloat(rawTotal) || 0;

    // CSV injection: prefix fields that start with =, +, -, @, or tab with a single quote
    const csvSafe = (val) => {
      const s = String(val);
      return /^[=+\-@\t]/.test(s) ? `'${s}` : s;
    };

    csvContent += `"${String(ord.id)}","${dateStr}",${csvSafe(customer)},${csvSafe(payment)},${csvSafe(status)},${total}\n`;
  });

  const encodedUri = encodeURI(csvContent);
  const link = document.createElement("a");
  link.setAttribute("href", encodedUri);
  link.setAttribute("download", `sales_report_${startDateStr}_to_${endDateStr}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
};