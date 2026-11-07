import { ref, onValue, set, update, remove } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { escapeHtml } from "./html-utils.js";
import { fileToDataUrl } from "./image-utils.js";

// Store settings the app reads at checkout:
//   settings/shippingFee                 number (PHP), the standard fee
//   settings/freeShippingMin             number (PHP), items total that makes shipping free; 0 = off
//   settings/provinceFees/{key}          { name, fee }, a different fee for one province
//   settings/appUpdate                   { latestBuild, versionName, apkUrl, message, updatedAt }, the newest APK
//   settings/autoCompleteDays            days after the estimated delivery when a shipped order completes itself
//   settings/paymentMethods/{key}        providerName, bankName, accountName,
//                                        accountNumber, qrImage (base64), updatedAt
// COD is built into the app and is not stored here.

// The app shows these four keys with fixed labels, so the admin uses the
// same labels to stay consistent with what customers see.
const KNOWN_LABELS = {
  gcash: 'GCash',
  maya: 'Maya',
  bpi: 'BPI Bank Transfer',
  bdo: 'BDO Bank Transfer'
};
const RESERVED_KEYS = ['cod'];

let paymentMethods = {};
let editingKey = '';
let currentQr = '';

function $(id) {
  return document.getElementById(id);
}

function setStatus(id, message, isError = false) {
  const el = $(id);
  if (!el) return;
  el.textContent = message;
  el.style.color = isError ? '#dc2626' : '#166534';
}

function formatPeso(value) {
  return `₱${Number(value).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function slugify(name) {
  return name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

export function initSettingsModule() {
  initShippingFee();
  initAppUpdate();
  initPaymentMethods();
}

// ---------------------------------------------------------------- shipping

const DEFAULT_AUTO_COMPLETE_DAYS = 3;

let shipping = { fee: null, freeMin: null, autoDays: null };
let provinceFees = {};

// Must match CheckoutSettings.provinceKey in the app and the database rules:
// "Rizal", " rizal " and "RIZAL." are all the key `rizal`.
function provinceKey(name) {
  return String(name).trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

function numberOrNull(value) {
  const n = Number(value);
  return value !== null && value !== undefined && Number.isFinite(n) ? n : null;
}

function renderShippingSummary() {
  const parts = [];
  if (shipping.fee === null) {
    parts.push('Standard fee not set yet: customers currently get free shipping.');
  } else {
    parts.push(`Standard fee: ${formatPeso(shipping.fee)}.`);
  }
  parts.push(shipping.freeMin > 0
    ? `Free shipping from ${formatPeso(shipping.freeMin)}.`
    : 'No free-shipping minimum.');
  parts.push(`Orders auto-complete ${shipping.autoDays ?? DEFAULT_AUTO_COMPLETE_DAYS} day(s) after the estimated delivery.`);
  $('shipping-fee-current').textContent = parts.join(' ');
}

function initShippingFee() {
  const input = $('shipping-fee-input');
  const freeInput = $('free-shipping-min-input');
  const daysInput = $('auto-complete-days-input');

  const watch = (key, field, onChange) => onValue(ref(db, `settings/${key}`), (snapshot) => {
    shipping[field] = snapshot.exists() ? numberOrNull(snapshot.val()) : null;
    onChange(shipping[field]);
    renderShippingSummary();
  }, (err) => {
    console.error(`Failed to load ${key}:`, err);
    setStatus('shipping-status', 'Could not load the shipping settings.', true);
  });

  watch('shippingFee', 'fee', (v) => { if (v !== null && document.activeElement !== input) input.value = v; });
  watch('freeShippingMin', 'freeMin', (v) => { if (document.activeElement !== freeInput) freeInput.value = v > 0 ? v : ''; });
  watch('autoCompleteDays', 'autoDays', (v) => { if (document.activeElement !== daysInput) daysInput.value = v ?? ''; });

  $('shipping-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const fee = parseFloat(input.value);
    const freeMin = freeInput.value.trim() === '' ? 0 : parseFloat(freeInput.value);
    const days = daysInput.value.trim() === '' ? DEFAULT_AUTO_COMPLETE_DAYS : parseInt(daysInput.value, 10);

    if (!Number.isFinite(fee) || fee < 0) {
      setStatus('shipping-status', 'Enter a standard shipping fee of 0 or more.', true);
      return;
    }
    if (!Number.isFinite(freeMin) || freeMin < 0) {
      setStatus('shipping-status', 'The free-shipping minimum must be 0 or more (or empty for none).', true);
      return;
    }
    if (!Number.isInteger(days) || days < 0 || days > 60) {
      setStatus('shipping-status', 'Auto-complete days must be a whole number from 0 to 60.', true);
      return;
    }

    try {
      await update(ref(db, 'settings'), {
        shippingFee: Math.round(fee * 100) / 100,
        freeShippingMin: Math.round(freeMin * 100) / 100,
        autoCompleteDays: days
      });
      setStatus('shipping-status', 'Shipping settings saved.');
      window.logAdminAction?.('SHIPPING_FEE_UPDATED',
        `Shipping fee ${formatPeso(fee)}, free shipping from ${freeMin > 0 ? formatPeso(freeMin) : 'none'}, auto-complete after ${days} day(s).`);
    } catch (err) {
      console.error('Failed to save shipping settings:', err);
      setStatus('shipping-status', 'Could not save the shipping settings. Please try again.', true);
    }
  });

  initProvinceFees();
}

// -------------------------------------------------------------- app update
//   settings/appUpdate   { latestBuild, versionName, apkUrl, message, updatedAt }
// The app compares latestBuild with its own build number (the +N in pubspec.yaml).

function initAppUpdate() {
  const build = $('app-update-build');
  const version = $('app-update-version');
  const url = $('app-update-url');
  const message = $('app-update-message');
  const updateRef = ref(db, 'settings/appUpdate');

  onValue(updateRef, (snapshot) => {
    const info = snapshot.val();
    if (!info) {
      $('app-update-current').textContent = 'No update published. Customers are not prompted.';
      return;
    }
    $('app-update-current').textContent =
      `Published: build ${info.latestBuild}${info.versionName ? ` (version ${info.versionName})` : ''}. ` +
      'Customers with an older build are prompted.';
    if (!$('app-update-form').contains(document.activeElement)) {
      build.value = info.latestBuild ?? '';
      version.value = info.versionName || '';
      url.value = info.apkUrl || '';
      message.value = info.message || '';
    }
  }, (err) => {
    console.error('Failed to load app update:', err);
    setStatus('app-update-status', 'Could not load the app update settings.', true);
  });

  $('app-update-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const latestBuild = parseInt(build.value, 10);
    const apkUrl = url.value.trim();

    if (!Number.isInteger(latestBuild) || latestBuild < 1) {
      setStatus('app-update-status', 'Enter the build number as a whole number, 1 or more.', true);
      return;
    }
    if (!/^https:\/\/[^\s]+$/i.test(apkUrl)) {
      setStatus('app-update-status', 'The download link must start with https://', true);
      return;
    }

    try {
      await set(updateRef, {
        latestBuild,
        versionName: version.value.trim(),
        apkUrl,
        message: message.value.trim(),
        updatedAt: Date.now()
      });
      setStatus('app-update-status', 'Update published. Customers on an older build will be prompted.');
      window.logAdminAction?.('APP_UPDATE_PUBLISHED', `App update published: build ${latestBuild}.`);
    } catch (err) {
      console.error('Failed to publish app update:', err);
      setStatus('app-update-status', 'Could not publish the update. Please try again.', true);
    }
  });

  $('app-update-clear').addEventListener('click', async () => {
    if (!confirm('Stop prompting customers to update?')) return;
    try {
      await remove(updateRef);
      setStatus('app-update-status', 'Update prompt removed.');
      window.logAdminAction?.('APP_UPDATE_CLEARED', 'App update prompt was removed.');
    } catch (err) {
      console.error('Failed to remove app update:', err);
      setStatus('app-update-status', 'Could not remove the update prompt. Please try again.', true);
    }
  });
}

// ---------------------------------------------------------- province fees
//   settings/provinceFees/{key}   { name, fee }

function initProvinceFees() {
  onValue(ref(db, 'settings/provinceFees'), (snapshot) => {
    provinceFees = snapshot.val() || {};
    renderProvinceFees();
  }, (err) => {
    console.error('Failed to load province fees:', err);
    $('province-fees-table-body').innerHTML =
      '<tr><td colspan="3" style="text-align:center; color:#dc2626;">Could not load province fees.</td></tr>';
  });

  $('province-fee-form').addEventListener('submit', saveProvinceFee);
  $('province-fees-table-body').addEventListener('click', handleProvinceClick);
}

async function saveProvinceFee(event) {
  event.preventDefault();
  const name = $('province-name-input').value.trim();
  const fee = parseFloat($('province-fee-input').value);
  const key = provinceKey(name);

  if (!key) {
    setStatus('province-status', 'Use letters or numbers in the province name.', true);
    return;
  }
  if (!Number.isFinite(fee) || fee < 0) {
    setStatus('province-status', 'Enter a fee of 0 or more.', true);
    return;
  }

  try {
    await set(ref(db, `settings/provinceFees/${key}`), { name, fee: Math.round(fee * 100) / 100 });
    const replaced = Boolean(provinceFees[key]);
    $('province-fee-form').reset();
    setStatus('province-status', `${name}: ${formatPeso(fee)} ${replaced ? 'updated' : 'saved'}.`);
    window.logAdminAction?.('PROVINCE_FEE_SAVED', `Shipping fee for ${name} set to ${formatPeso(fee)}.`);
  } catch (err) {
    console.error('Failed to save province fee:', err);
    setStatus('province-status', 'Could not save the province fee. Please try again.', true);
  }
}

async function removeProvinceFee(key) {
  const name = provinceFees[key]?.name || key;
  if (!confirm(`Remove the fee for "${name}"? Customers there will pay the standard fee.`)) return;
  try {
    await remove(ref(db, `settings/provinceFees/${key}`));
    window.logAdminAction?.('PROVINCE_FEE_REMOVED', `Shipping fee for ${name} was removed.`);
  } catch (err) {
    console.error('Failed to remove province fee:', err);
    setStatus('province-status', 'Could not remove the province fee. Please try again.', true);
  }
}

function handleProvinceClick(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const key = button.dataset.key;
  if (button.dataset.action === 'remove') removeProvinceFee(key);
  if (button.dataset.action === 'edit') {
    const entry = provinceFees[key];
    if (!entry) return;
    $('province-name-input').value = entry.name || key;
    $('province-fee-input').value = entry.fee;
    $('province-fee-input').focus();
  }
}

function renderProvinceFees() {
  const tbody = $('province-fees-table-body');
  const entries = Object.entries(provinceFees)
    .filter(([, v]) => v && typeof v === 'object' && Number.isFinite(Number(v.fee)))
    .sort(([, a], [, b]) => String(a.name).localeCompare(String(b.name)));

  if (entries.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; color:#64748b;">No province fees yet. Every order pays the standard fee.</td></tr>';
    return;
  }

  tbody.innerHTML = entries.map(([key, v]) => `
    <tr>
      <td style="font-weight:600; color:#1e293b;">${escapeHtml(v.name || key)}</td>
      <td>${formatPeso(v.fee)}</td>
      <td>
        <button class="btn btn-warning" style="padding:4px 10px; font-size:12px;" data-action="edit" data-key="${escapeHtml(key)}">Edit</button>
        <button class="btn btn-danger" style="padding:4px 10px; font-size:12px;" data-action="remove" data-key="${escapeHtml(key)}">Remove</button>
      </td>
    </tr>
  `).join('');
}

// --------------------------------------------------------- payment methods

function initPaymentMethods() {
  onValue(ref(db, 'settings/paymentMethods'), (snapshot) => {
    paymentMethods = snapshot.val() || {};
    renderPaymentMethodsTable();
    window.hideLoading('settings');
  }, (err) => {
    console.error('Failed to load payment methods:', err);
    $('payment-methods-table-body').innerHTML =
      '<tr><td colspan="5" style="text-align:center; color:#dc2626;">Could not load payment methods.</td></tr>';
  });

  $('pm-qr-file').addEventListener('change', handleQrUpload);
  $('payment-method-form').addEventListener('submit', savePaymentMethod);
  $('pm-cancel-btn').addEventListener('click', resetPaymentForm);
  $('payment-methods-table-body').addEventListener('click', handleTableClick);
}

async function handleQrUpload(event) {
  const file = event.target.files[0];
  if (!file) return;

  try {
    currentQr = await fileToDataUrl(file, { maxSize: 480, type: 'image/png' });
    renderQrPreview();
    setStatus('pm-status', '');
  } catch (err) {
    event.target.value = '';
    setStatus('pm-status', err.message, true);
  }
}

function renderQrPreview() {
  const box = $('pm-qr-preview');
  box.innerHTML = '';
  if (!currentQr) return;

  const img = document.createElement('img');
  img.src = currentQr;
  img.alt = 'QR preview';
  img.style.cssText = 'width:100px;height:100px;object-fit:contain;border-radius:6px;border:1px solid #cbd5e1;';
  box.appendChild(img);
}

async function savePaymentMethod(event) {
  event.preventDefault();

  const name = $('pm-name').value.trim();
  const bankName = $('pm-bank').value.trim();
  const accountName = $('pm-account-name').value.trim();
  const accountNumber = $('pm-account-number').value.trim();

  const key = editingKey || slugify(name);
  if (!key) {
    setStatus('pm-status', 'Use letters or numbers in the method name.', true);
    return;
  }
  if (RESERVED_KEYS.includes(key)) {
    setStatus('pm-status', 'COD is built into the app. Choose a different name.', true);
    return;
  }
  if (!editingKey && paymentMethods[key]) {
    setStatus('pm-status', 'A method with this name already exists. Use Edit to change it.', true);
    return;
  }
  // Input validation
  if (accountNumber && !/^\d+$/.test(accountNumber)) {
    setStatus('pm-status', 'Account / mobile number must be numeric.', true);
    return;
  }
  if (bankName.length > 100) {
    setStatus('pm-status', 'Bank name must be 100 characters or less.', true);
    return;
  }
  if (accountName.length > 100) {
    setStatus('pm-status', 'Account name must be 100 characters or less.', true);
    return;
  }

  try {
    await set(ref(db, `settings/paymentMethods/${key}`), {
      providerName: KNOWN_LABELS[key] || name,
      bankName,
      accountName,
      accountNumber,
      qrImage: currentQr,
      updatedAt: Date.now()
    });
    window.logAdminAction?.('PAYMENT_METHOD_SAVED', `Payment method "${name}" was saved.`);
    resetPaymentForm();
    setStatus('pm-status', `"${name}" saved.`);
  } catch (err) {
    console.error('Failed to save payment method:', err);
    setStatus('pm-status', 'Could not save the payment method. Please try again.', true);
  }
}

function resetPaymentForm() {
  $('payment-method-form').reset();
  editingKey = '';
  currentQr = '';
  renderQrPreview();
  $('pm-form-title').textContent = 'Add Payment Method';
  $('pm-save-btn').textContent = 'Save Payment Method';
  $('pm-cancel-btn').hidden = true;
  setStatus('pm-status', '');
}

function startEdit(key) {
  const method = paymentMethods[key];
  if (!method) return;

  editingKey = key;
  currentQr = method.qrImage || '';
  $('pm-name').value = method.providerName || key;
  $('pm-bank').value = method.bankName || '';
  $('pm-account-name').value = method.accountName || '';
  $('pm-account-number').value = method.accountNumber || '';
  $('pm-qr-file').value = '';
  renderQrPreview();

  $('pm-form-title').textContent = 'Edit Payment Method';
  $('pm-save-btn').textContent = 'Update Payment Method';
  $('pm-cancel-btn').hidden = false;
  setStatus('pm-status', '');
  $('pm-name').focus();
}

async function removeMethod(key) {
  const label = paymentMethods[key]?.providerName || key;
  if (!confirm(`Remove "${label}"? Customers will no longer see it at checkout.`)) return;

  try {
    await remove(ref(db, `settings/paymentMethods/${key}`));
    window.logAdminAction?.('PAYMENT_METHOD_REMOVED', `Payment method "${label}" was removed.`);
    if (editingKey === key) resetPaymentForm();
  } catch (err) {
    console.error('Failed to remove payment method:', err);
    setStatus('pm-status', 'Could not remove the payment method. Please try again.', true);
  }
}

function handleTableClick(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;

  const key = button.dataset.key;
  if (button.dataset.action === 'edit') startEdit(key);
  if (button.dataset.action === 'remove') removeMethod(key);
}

function renderPaymentMethodsTable() {
  const tbody = $('payment-methods-table-body');
  const entries = Object.entries(paymentMethods).filter(([, method]) => method && typeof method === 'object');

  if (entries.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#64748b;">No payment methods yet. Customers can only choose Cash on Delivery.</td></tr>';
    return;
  }

  tbody.innerHTML = entries.map(([key, method]) => {
    const bank = method.bankName && method.bankName.toLowerCase() !== key
      ? `<div style="font-size:12px; color:#64748b;">${escapeHtml(method.bankName)}</div>`
      : '';
    const qr = method.qrImage
      ? `<img src="${escapeHtml(method.qrImage)}" alt="QR" style="width:40px; height:40px; object-fit:contain; border-radius:4px; border:1px solid #cbd5e1;">`
      : '<span style="color:#64748b; font-size:12px;">None</span>';

    return `
      <tr>
        <td style="font-weight:600; color:#1e293b;">${escapeHtml(method.providerName || key)}${bank}</td>
        <td>${escapeHtml(method.accountName || 'N/A')}</td>
        <td>${escapeHtml(method.accountNumber || 'N/A')}</td>
        <td>${qr}</td>
        <td>
          <button class="btn btn-warning" style="padding:4px 10px; font-size:12px;" data-action="edit" data-key="${escapeHtml(key)}">Edit</button>
          <button class="btn btn-danger" style="padding:4px 10px; font-size:12px;" data-action="remove" data-key="${escapeHtml(key)}">Remove</button>
        </td>
      </tr>
    `;
  }).join('');
}