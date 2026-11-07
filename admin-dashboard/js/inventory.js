import { notify } from "./toast.js";
import { ref, onValue, update, push, get } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";

let rawInventoryData = {};
let selectedOrderId = null; // reserved for future use

export function initInventoryModule() {
  const productsRef = ref(db, 'products');

  onValue(productsRef, (snapshot) => {
    rawInventoryData = snapshot.val() || {};
    renderInventoryDashboard();
    window.hideLoading('inventory');
  });

  document.getElementById('inv-search-input')?.addEventListener('input', renderInventoryTable);
  document.getElementById('inv-filter-status')?.addEventListener('change', renderInventoryTable);

  // Stock Adjustment Modal buttons
  document.getElementById('adj-btn-in')?.addEventListener('click', () => setMovementType('in'));
  document.getElementById('adj-btn-out')?.addEventListener('click', () => setMovementType('out'));
  document.getElementById('stock-adjust-form')?.addEventListener('submit', (e) => {
    e.preventDefault();
    window.submitStockAdjust();
  });
}

function setMovementType(type) {
  document.getElementById('adj-movement-type').value = type;
  const btnIn = document.getElementById('adj-btn-in');
  const btnOut = document.getElementById('adj-btn-out');
  if (type === 'in') {
    btnIn.className = 'btn btn-success';
    btnOut.className = 'btn btn-outline';
  } else {
    btnOut.className = 'btn btn-danger';
    btnIn.className = 'btn btn-outline';
  }
}

function getProductList() {
  if (!rawInventoryData) return [];
  if (Array.isArray(rawInventoryData)) {
    return rawInventoryData
      .map((prod, index) => [index, prod])
      .filter(([_, prod]) => prod !== null && typeof prod === 'object');
  }
  return Object.entries(rawInventoryData)
    .filter(([_, prod]) => prod !== null && typeof prod === 'object');
}

function renderInventoryDashboard() {
  let totalItems = 0;
  let lowStockCount = 0;
  let outOfStockCount = 0;
  let totalValuation = 0;

  const productEntries = getProductList();
  const inventoryList = [];

  productEntries.forEach(([id, prod]) => {
    totalItems++;
    const stock = parseInt(prod.productStock ?? prod.stock ?? 0, 10);
    
    let rawPrice = prod.productPrice ?? prod.price ?? 0;
    if (typeof rawPrice === 'string') rawPrice = rawPrice.replace(/[^0-9.-]+/g, "");
    const price = parseFloat(rawPrice) || 0;

    totalValuation += (price * stock);

    if (stock === 0) {
      outOfStockCount++;
    } else if (stock <= 5) {
      lowStockCount++;
    }

    inventoryList.push({ id, ...prod, stock });
  });

  updateStockAlertBanner(inventoryList);

  const valEl = document.getElementById('inv-stat-valuation');
  const lowEl = document.getElementById('inv-stat-low');
  const outEl = document.getElementById('inv-stat-out');
  const totalEl = document.getElementById('inv-stat-total');

  if (valEl) valEl.innerText = `₱${totalValuation.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  if (lowEl) lowEl.innerText = lowStockCount;
  if (outEl) outEl.innerText = outOfStockCount;
  if (totalEl) totalEl.innerText = totalItems;

  renderInventoryTable();
}

function updateStockAlertBanner(inventoryList) {
  const banner = document.getElementById('stock-alert-banner');
  const alertText = document.getElementById('stock-alert-text');
  if (!banner || !alertText) return;

  const lowStockItems = inventoryList.filter(item => item.stock <= 5);

  if (lowStockItems.length > 0) {
    const outOfStockCount = lowStockItems.filter(item => item.stock === 0).length;
    alertText.innerText = `${lowStockItems.length} item(s) require attention (${outOfStockCount} out of stock, ${lowStockItems.length - outOfStockCount} low stock).`;
    banner.style.display = 'flex';
  } else {
    banner.style.display = 'none';
  }
}

function renderInventoryTable() {
  const tbody = document.getElementById('inventory-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('inv-search-input')?.value || '').toLowerCase();
  const filterStatus = document.getElementById('inv-filter-status')?.value || 'ALL';

  const productEntries = getProductList();

  let filtered = productEntries.filter(([_, prod]) => {
    const name = (prod.productName || prod.name || '').toLowerCase();
    const stock = parseInt(prod.productStock ?? prod.stock ?? 0, 10);

    const matchesSearch = name.includes(searchQuery);
    
    let matchesStatus = true;
    if (filterStatus === 'LOW') matchesStatus = stock > 0 && stock <= 5;
    else if (filterStatus === 'OUT') matchesStatus = stock === 0;
    else if (filterStatus === 'IN_STOCK') matchesStatus = stock > 5;

    return matchesSearch && matchesStatus;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:#64748b;">No matching inventory items found.</td></tr>';
    return;
  }

  const fragment = document.createDocumentFragment();

  filtered.forEach(([id, prod]) => {
    const name = prod.productName || prod.name || 'Unnamed Product';
    const category = prod.category || prod.productCategory || 'Uncategorized';
    
    let rawPrice = prod.productPrice ?? prod.price ?? 0;
    if (typeof rawPrice === 'string') rawPrice = rawPrice.replace(/[^0-9.-]+/g, "");
    const price = parseFloat(rawPrice) || 0;

    const stock = parseInt(prod.productStock ?? prod.stock ?? 0, 10);
    const totalAssetValue = price * stock;

    let stockBadge = `<span class="badge badge-completed">In Stock (${stock})</span>`;
    if (stock === 0) {
      stockBadge = `<span class="badge badge-cancelled">Out of Stock</span>`;
    } else if (stock <= 5) {
      stockBadge = `<span class="badge badge-pending">Low Stock (${stock})</span>`;
    }

    const tr = document.createElement('tr');
    tr.className = 'clickable-row';
    tr.innerHTML = `
      <td style="font-weight:600; color:#2563eb;" onclick="window.viewInventoryItemModule(${jsArg(id)})">${escapeHtml(name)}</td>
      <td onclick="window.viewInventoryItemModule(${jsArg(id)})"><span style="background:#e0f2fe; color:#0369a1; padding:3px 8px; border-radius:12px; font-size:11px; font-weight:600;">${escapeHtml(category)}</span></td>
      <td onclick="window.viewInventoryItemModule(${jsArg(id)})">₱${price.toFixed(2)}</td>
      <td onclick="window.viewInventoryItemModule(${jsArg(id)})">${stockBadge}</td>
      <td style="font-weight:600;" onclick="window.viewInventoryItemModule(${jsArg(id)})">₱${totalAssetValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
      <td style="text-align:center;">
        <button type="button" class="btn btn-primary adj-stock-btn" style="padding:6px 12px; font-size:12px;">Adjust Stock</button>
      </td>
    `;

    // Attach click listener to the Adjust Stock button to prevent event bubbling to row
    const adjBtn = tr.querySelector('.adj-stock-btn');
    adjBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      window.openAdjustStockModal(id, name, stock);
    });

    fragment.appendChild(tr);
  });

  tbody.appendChild(fragment);
}

window.openAdjustStockModal = function(productId, productName, currentStock) {
  document.getElementById('adj-product-id').value = productId;
  document.getElementById('adj-product-name').value = productName;
  document.getElementById('adj-current-stock').value = currentStock;
  document.getElementById('adj-quantity').value = '';
  document.getElementById('adj-category').value = 'restock';
  document.getElementById('adj-reason').value = '';
  setMovementType('in');
  
  document.getElementById('stock-adjust-modal').classList.add('active');
};

window.closeStockAdjustModal = function() {
  document.getElementById('stock-adjust-modal').classList.remove('active');
};

let adjustBusy = false;

window.submitStockAdjust = async function() {
  if (adjustBusy) return;

  const productId = document.getElementById('adj-product-id').value;
  const productName = document.getElementById('adj-product-name').value;
  const type = document.getElementById('adj-movement-type').value;
  const quantity = parseInt(document.getElementById('adj-quantity').value, 10);
  const categorySelect = document.getElementById('adj-category');
  const category = categorySelect.value;
  // The database rules require a non-empty reason, so fall back to the category label.
  const reason = document.getElementById('adj-reason').value.trim()
    || categorySelect.selectedOptions[0]?.textContent.trim()
    || category;
  const performedBy = document.getElementById('adj-performed-by')?.value.trim() || 'admin';

  if (!quantity || quantity <= 0) {
    notify('Please enter a valid quantity.');
    return;
  }

  adjustBusy = true;
  try {
    // Re-read the live stock so a stale table (or a second admin) can't cause a wrong total.
    const liveSnap = await get(ref(db, `products/${productId}`));
    const live = liveSnap.val() || {};
    const currentStock = parseInt(live.productStock ?? live.stock ?? 0, 10) || 0;

    if (type === 'out' && quantity > currentStock) {
      notify('Not enough stock. Only ' + currentStock + ' unit(s) available.');
      return;
    }

    const newStock = type === 'in' ? currentStock + quantity : currentStock - quantity;
    const movementKey = push(ref(db, 'stockMovements')).key;

    // One atomic write: the stock change and its log entry both succeed or both fail.
    await update(ref(db), {
      [`products/${productId}/productStock`]: newStock,
      [`stockMovements/${movementKey}`]: {
        productId,
        productName,
        type,
        quantity,
        previousStock: currentStock,
        newStock,
        reason,
        category,
        notes: '',
        performedBy,
        performedAt: Date.now()
      }
    });

    window.closeStockAdjustModal();
    notify('Stock adjusted successfully.');
  } catch (err) {
    console.error('Failed to adjust stock:', err);
    notify('Failed to adjust stock level.');
  } finally {
    adjustBusy = false;
  }
};

// Open View-Only Item Description Modal
window.viewInventoryItemModule = function(id) {
  let prod = null;
  if (Array.isArray(rawInventoryData)) {
    prod = rawInventoryData[id];
  } else if (rawInventoryData) {
    prod = rawInventoryData[id];
  }

  if (!prod) return;

  const name = prod.productName || prod.name || 'Unnamed Product';
  const category = prod.category || prod.productCategory || 'Uncategorized';
  
  let rawPrice = prod.productPrice ?? prod.price ?? 0;
  if (typeof rawPrice === 'string') rawPrice = rawPrice.replace(/[^0-9.-]+/g, "");
  const price = parseFloat(rawPrice) || 0;

  const stock = parseInt(prod.productStock ?? prod.stock ?? 0, 10);
  const totalAssetValue = price * stock;
  const description = prod.productDescription || prod.description || 'No description available for this item.';
  const imageUrl = prod.imageUrl || prod.image || '';

  document.getElementById('inv-modal-name').innerText = name;
  document.getElementById('inv-modal-category').innerText = category;
  document.getElementById('inv-modal-price').innerText = `₱${price.toFixed(2)}`;
  document.getElementById('inv-modal-stock').innerText = stock;
  document.getElementById('inv-modal-asset').innerText = `₱${totalAssetValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  document.getElementById('inv-modal-desc').innerText = description;

  const imgContainer = document.getElementById('inv-modal-image-container');
  if (imageUrl) {
    imgContainer.innerHTML = `<img src="${escapeHtml(imageUrl)}" style="width:100%; height:100%; object-fit:cover;">`;
  } else {
    imgContainer.innerHTML = `<span style="font-size:12px; color:#64748b;">No Image</span>`;
  }

  document.getElementById('inventory-modal').classList.add('active');
};

// Close View Modal
window.closeInventoryModal = function() {
  document.getElementById('inventory-modal').classList.remove('active');
};

// Close when clicking outside modal content
window.addEventListener('click', (e) => {
  const modal = document.getElementById('inventory-modal');
  if (e.target === modal) window.closeInventoryModal();
  const stockModal = document.getElementById('stock-adjust-modal');
  if (e.target === stockModal) window.closeStockAdjustModal();
});
