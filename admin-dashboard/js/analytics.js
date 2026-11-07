import { ref, onValue } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml } from "./html-utils.js";

let statusChartInstance = null;
let categoryChartInstance = null;
let topProductsChartInstance = null;
let dailyRevenueChartInstance = null;

let cachedTx = {};
let revenueRange = 7;

// Local-date key (YYYY-MM-DD). toISOString() is UTC, which shifted every day
// back by one in UTC+8 and hid today's sales from the revenue chart.
const dayKey = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const peso = (n) => '₱' + Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const pesoShort = (n) => '₱' + Number(n || 0).toLocaleString('en-US', { maximumFractionDigits: 0 });
const setText = (id, v) => { const el = document.getElementById(id); if (el) el.innerText = v; };
const toNumber = (v) => parseFloat(typeof v === 'string' ? v.replace(/[^0-9.-]+/g, '') : v) || 0;

export function initAnalyticsModule() {
  const productsRef = ref(db, 'products');
  const transactionsRef = ref(db, 'transactions');

  document.getElementById('revenue-range')?.addEventListener('change', (e) => {
    revenueRange = parseInt(e.target.value, 10) || 7;
    renderTransactions();
  });

  // Products: count, category chart, low-stock stat + list
  onValue(productsRef, (snapshot) => {
    const products = Object.values(snapshot.val() || {}).filter((p) => p && typeof p === 'object');
    const categoryCounts = {};
    const lowStock = [];

    products.forEach((prod) => {
      const cat = prod.category || prod.productCategory || 'Uncategorized';
      categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
      const stock = parseInt(prod.productStock ?? prod.stock ?? 0, 10) || 0;
      if (stock <= 5) lowStock.push({ name: prod.productName || prod.name || 'Unnamed Product', stock });
    });

    updateProductsUI(products.length, categoryCounts);
    setText('stat-lowstock', lowStock.length);
    renderLowStockList(lowStock.sort((a, b) => a.stock - b.stock).slice(0, 6));
    window.hideLoading('analytics');
  });

  // Transactions: stats, status chart, top products, revenue chart, recent orders
  onValue(transactionsRef, (snapshot) => {
    cachedTx = snapshot.val() || {};
    renderTransactions();
    window.hideLoading('analytics');
  });
}

function renderTransactions() {
  const entries = Object.entries(cachedTx || {}).filter(([, ord]) => ord);

  let pendingCount = 0;
  let totalRevenue = 0;
  let countedOrders = 0;
  let todaySales = 0;
  let toVerify = 0;
  const statusCounts = {
    Pending: 0, Processing: 0, Shipping: 0, Completed: 0,
    Cancelled: 0, 'Payment Rejected': 0, Returned: 0
  };
  const productRevenue = {};

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayKey = dayKey(today);
  const dailyRevenue = {};
  for (let i = 0; i < revenueRange; i++) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    dailyRevenue[dayKey(d)] = 0;
  }

  entries.forEach(([, ord]) => {
    const status = ord.status || 'Pending';
    statusCounts[status] = (statusCounts[status] || 0) + 1;

    const lower = status.toLowerCase();
    if (['pending', 'processing', 'shipping'].includes(lower)) pendingCount++;
    if (status === 'Pending' && (ord.paymentStatus || ord.paymentVerificationStatus) === 'pending_verification') toVerify++;

    if (['cancelled', 'payment rejected', 'returned'].includes(lower)) return;

    const total = toNumber(ord.grandTotal ?? 0);
    totalRevenue += total;
    countedOrders++;

    if (ord.createdAt > 0) {
      const key = dayKey(new Date(ord.createdAt));
      if (key === todayKey) todaySales += total;
      if (dailyRevenue[key] !== undefined) dailyRevenue[key] += total;
    }

    const items = ord.items || [];
    (Array.isArray(items) ? items : Object.values(items)).forEach((it) => {
      if (!it) return;
      const name = it.productName || 'Unknown Product';
      productRevenue[name] = (productRevenue[name] || 0) + (parseInt(it.quantity) || 0) * (parseFloat(it.price) || 0);
    });
  });

  updateOrdersUI(entries.length, pendingCount, totalRevenue, statusCounts);
  updateTopProductsUI(productRevenue);
  updateDailyRevenueUI(dailyRevenue);

  setText('stat-today', peso(todaySales));
  setText('stat-aov', peso(countedOrders ? totalRevenue / countedOrders : 0));
  setText('stat-verify', toVerify);
  setText('revenue-chart-title', `Daily Revenue (Last ${revenueRange} Days)`);

  const recent = entries
    .sort((a, b) => (b[1].createdAt || 0) - (a[1].createdAt || 0))
    .slice(0, 5);
  renderRecentOrders(recent);
}

function renderRecentOrders(recent) {
  const body = document.getElementById('recent-orders-body');
  if (!body) return;
  if (recent.length === 0) {
    body.innerHTML = '<tr><td colspan="4" style="text-align:center; color:#64748b;">No orders yet.</td></tr>';
    return;
  }
  body.innerHTML = recent.map(([id, ord]) => {
    const status = ord.status || 'Pending';
    return `<tr class="clickable-row" onclick="switchTab('orders')">
      <td style="color:#2563eb; font-weight:600; font-size:12px;">#${escapeHtml(String(id).substring(0, 8))}</td>
      <td>${escapeHtml(ord.recipientName || 'N/A')}</td>
      <td><span class="badge badge-${escapeHtml(status.toLowerCase().replace(/\s+/g, '-'))}">${escapeHtml(status)}</span></td>
      <td style="font-weight:600;">${peso(toNumber(ord.grandTotal ?? 0))}</td>
    </tr>`;
  }).join('');
}

function renderLowStockList(items) {
  const body = document.getElementById('low-stock-body');
  if (!body) return;
  if (items.length === 0) {
    body.innerHTML = '<tr><td colspan="2" style="text-align:center; color:#64748b;">All products are well stocked.</td></tr>';
    return;
  }
  body.innerHTML = items.map((it) => `<tr class="clickable-row" onclick="switchTab('inventory')">
      <td>${escapeHtml(it.name)}</td>
      <td>${it.stock === 0
        ? '<span class="badge badge-cancelled">Out of Stock</span>'
        : `<span class="badge badge-pending">${it.stock} left</span>`}</td>
    </tr>`).join('');
}

function updateProductsUI(count, categoryCounts) {
  const el = document.getElementById('stat-products');
  if (el) el.innerText = count;

  renderCategoryChart(categoryCounts);
}

function updateOrdersUI(orders, pending, revenue, statusCounts) {
  const ordersEl = document.getElementById('stat-orders');
  const pendingEl = document.getElementById('stat-pending');
  const revenueEl = document.getElementById('stat-revenue');

  if (ordersEl) ordersEl.innerText = orders;
  if (pendingEl) pendingEl.innerText = pending;
  if (revenueEl) revenueEl.innerText = peso(revenue);

  renderStatusChart(statusCounts);
}

function updateTopProductsUI(productRevenue) {
  const top = Object.entries(productRevenue)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);
  renderTopProductsChart(top);
}

function updateDailyRevenueUI(dailyRevenue) {
  // Sort ascending by date for line chart
  const sorted = Object.entries(dailyRevenue).sort((a, b) => a[0].localeCompare(b[0]));
  renderDailyRevenueChart(sorted);
}

// Render Order Status Chart (Doughnut)
function renderStatusChart(statusCounts) {
  const ctx = document.getElementById('statusChart');
  if (!ctx) return;

  if (statusChartInstance) {
    statusChartInstance.destroy();
  }

  const statusColors = {
    Pending: '#f59e0b',
    Processing: '#6366f1',
    Shipping: '#0284c7',
    Completed: '#16a34a',
    Cancelled: '#dc2626',
    'Payment Rejected': '#ef4444',
    Returned: '#d97706'
  };

  const labels = Object.keys(statusCounts);
  const data = Object.values(statusCounts);
  const colors = labels.map((label) => statusColors[label] || '#6b7280');

  statusChartInstance = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: labels,
      datasets: [{
        data: data,
        backgroundColor: colors,
        borderWidth: 2,
        borderColor: '#ffffff'
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'bottom' }
      }
    }
  });
}

// Render Category Breakdown Chart (Bar)
function renderCategoryChart(categoryCounts) {
  const ctx = document.getElementById('categoryChart');
  if (!ctx) return;

  if (categoryChartInstance) {
    categoryChartInstance.destroy();
  }

  categoryChartInstance = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: Object.keys(categoryCounts),
      datasets: [{
        label: 'Products',
        data: Object.values(categoryCounts),
        backgroundColor: '#2563eb',
        borderRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true, ticks: { stepSize: 1 } }
      },
      plugins: {
        legend: { display: false }
      }
    }
  });
}

// Render Top Products Chart (Bar) - top 10 products by revenue
function renderTopProductsChart(topProducts) {
  const ctx = document.getElementById('topProductsChart');
  if (!ctx) return;

  if (topProductsChartInstance) {
    topProductsChartInstance.destroy();
  }

  const labels = topProducts.map(([name]) => name.length > 26 ? name.slice(0, 23) + '...' : name);
  const data = topProducts.map(([, revenue]) => revenue);

  topProductsChartInstance = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [{
        label: 'Revenue (₱)',
        data: data,
        backgroundColor: '#2563eb',
        borderRadius: 6
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        x: { beginAtZero: true, ticks: { callback: (v) => pesoShort(v) }, title: { display: true, text: 'Revenue (₱)', font: { size: 11 } } },
        y: { title: { display: true, text: 'Product', font: { size: 11 } } }
      },
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { title: (items) => topProducts[items[0].dataIndex][0], label: (ctx) => peso(ctx.parsed.x) } }
      }
    }
  });
}

// Render Daily Revenue Chart (Line) - last 7 days
function renderDailyRevenueChart(dailyData) {
  const ctx = document.getElementById('dailyRevenueChart');
  if (!ctx) return;

  if (dailyRevenueChartInstance) {
    dailyRevenueChartInstance.destroy();
  }

  const labels = dailyData.map(([date]) => {
    const d = new Date(date + 'T00:00:00');
    return d.toLocaleDateString(undefined, revenueRange > 7 ? { month: 'short', day: 'numeric' } : { weekday: 'short', month: 'short', day: 'numeric' });
  });
  const data = dailyData.map(([, revenue]) => revenue);

  dailyRevenueChartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Revenue (₱)',
        data: data,
        borderColor: '#16a34a',
        backgroundColor: 'rgba(22, 163, 74, 0.1)',
        fill: true,
        cubicInterpolationMode: 'monotone',
        tension: 0.35,
        pointRadius: revenueRange > 7 ? 2 : 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true, ticks: { callback: (v) => pesoShort(v) }, title: { display: true, text: 'Revenue (₱)', font: { size: 11 } } },
        x: { title: { display: true, text: 'Date', font: { size: 11 } } }
      },
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: (ctx) => peso(ctx.parsed.y) } }
      }
    }
  });
}