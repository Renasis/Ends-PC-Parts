import { ref, onValue, set, remove } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";

let rawPromosCache = {};
let pendingDeleteCode = null;

export function initPromosModule() {
  const promosRef = ref(db, 'promos');

  onValue(promosRef, (snapshot) => {
    rawPromosCache = snapshot.val() || {};
    renderPromosTable();
    window.hideLoading('promos');
  }, (err) => {
    console.error('Could not load promo codes:', err);
    const tbody = document.getElementById('promos-table-body');
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#dc2626;">Could not load promo codes. Publish the latest database rules in Firebase and make sure this account is an admin.</td></tr>';
    }
    window.hideLoading('promos');
  });
}

function showToast(message, isError = false) {
  const toast = document.getElementById('promo-toast');
  const msgEl = document.getElementById('promo-toast-msg');
  if (!toast || !msgEl) return;

  msgEl.innerText = message;
  toast.style.background = isError ? '#dc2626' : '#1e293b';
  toast.style.display = 'block';
  toast.style.opacity = '1';

  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => {
      toast.style.display = 'none';
    }, 300);
  }, 3000);
}

window.savePromoCode = async function(event) {
  event.preventDefault();

  const code = document.getElementById('promo-code').value.trim().toUpperCase();
  const type = document.getElementById('promo-type').value;
  const value = parseFloat(document.getElementById('promo-value').value) || 0;
  const minSpend = parseFloat(document.getElementById('promo-min-spend').value) || 0;

  // Input validation
  if (!code || !/^[A-Z0-9]{4,20}$/.test(code)) {
    showToast("Promo code must be 4-20 characters, uppercase letters and numbers only.", true);
    return;
  }
  if (value <= 0) {
    showToast("Discount value must be greater than 0.", true);
    return;
  }
  if (minSpend < 0) {
    showToast("Minimum spend cannot be negative.", true);
    return;
  }

  const promoRef = ref(db, `promos/${code}`);

  try {
    await set(promoRef, {
      code: code,
      discountType: type,
      discountValue: value,
      minSpend: minSpend,
      createdAt: Date.now()
    });

    showToast(`Promo code ${code} created successfully!`);
    document.getElementById('promo-form').reset();
  } catch (err) {
    console.error("Failed to save promo code:", err);
    showToast("Failed to save promo code to Firebase.", true);
  }
};

function renderPromosTable() {
  const tbody = document.getElementById('promos-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!rawPromosCache || Object.keys(rawPromosCache).length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#64748b;">No active promo codes found.</td></tr>';
    return;
  }

  Object.entries(rawPromosCache).forEach(([key, promo]) => {
    if (!promo) return;

    const typeStr = promo.discountType === 'percentage' ? 'Percentage (%)' : 'Fixed Amount (₱)';
    const valStr = promo.discountType === 'percentage' ? `${promo.discountValue}%` : `₱${parseFloat(promo.discountValue).toFixed(2)}`;
    const minSpendStr = `₱${parseFloat(promo.minSpend || 0).toFixed(2)}`;

    tbody.innerHTML += `
      <tr>
        <td style="font-weight:600; color:#2563eb;">${escapeHtml(promo.code || key)}</td>
        <td>${typeStr}</td>
        <td style="font-weight:600; color:#166534;">${valStr}</td>
        <td>${escapeHtml(minSpendStr)}</td>
        <td>
          <button class="btn btn-danger" style="padding: 4px 10px; font-size: 12px;" onclick="window.promptDeletePromo(${jsArg(key)})">Remove</button>
        </td>
      </tr>
    `;
  });
}

window.promptDeletePromo = function(codeKey) {
  pendingDeleteCode = codeKey;
  const modalText = document.getElementById('promo-confirm-text');
  if (modalText) {
    modalText.innerText = `Are you sure you want to delete promo code "${codeKey}"?`;
  }
  
  const confirmBtn = document.getElementById('promo-confirm-btn');
  if (confirmBtn) {
    confirmBtn.onclick = window.confirmDeletePromo;
  }

  document.getElementById('promo-confirm-modal')?.classList.add('active');
};

window.closePromoConfirm = function() {
  document.getElementById('promo-confirm-modal')?.classList.remove('active');
  pendingDeleteCode = null;
};

window.confirmDeletePromo = async function() {
  if (!pendingDeleteCode) return;

  const codeKey = pendingDeleteCode;
  window.closePromoConfirm();

  try {
    await remove(ref(db, `promos/${codeKey}`));
    showToast(`Promo code ${codeKey} deleted successfully.`);
  } catch (err) {
    console.error("Failed to delete promo code:", err);
    showToast("Failed to delete promo code.", true);
  }
};