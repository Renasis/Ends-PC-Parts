import { notify } from "./toast.js";
import { ref, onValue, push, update, query, limitToFirst } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";
import { fileToDataUrl, resizeDataUrl } from "./image-utils.js";
import { notifyPriceChange } from "./notifications.js";
import { escapeHtml, jsArg } from "./html-utils.js";

// Every product keeps two pictures:
//  - a small thumbnail in products/{id}/imageUrl (the app's list, cart, etc.)
//  - the full picture in productImages/{id} (the app's product page only)
// This keeps the product list the app downloads small, which matters on the
// free Firebase plan.
const THUMB_OPTIONS = { maxSize: 200, quality: 0.6 };
const FULL_OPTIONS = { maxSize: 720, quality: 0.75 };

// An imageUrl longer than this (about 30 KB) is an old full-size picture.
const BIG_IMAGE_CHARS = 40000;

let rawProductsData = {};
let newImages = null; // { thumb, full } for a picture chosen in the form
let newGalleryImages = []; // [{ thumb, full }] for additional gallery images
let variantRowCount = 0;

// Staff can fix a product's name, category, description and pictures. Price,
// stock, variants, adding and deleting stay with admins (and the database
// rules refuse them even if this screen were bypassed).
const isStaff = () => document.body.classList.contains('role-staff');

export function initProductsModule() {
  const productsRef = query(ref(db, 'products'), limitToFirst(500));

  onValue(productsRef, (snapshot) => {
    rawProductsData = snapshot.val() || {};
    renderProductsTable();
    window.hideLoading('products');
  });

  // Attach Filter Listeners
  document.getElementById('p-search-input')?.addEventListener('input', renderProductsTable);
  document.getElementById('p-filter-category')?.addEventListener('change', renderProductsTable);

  setupImageConverter();

  if (isStaff()) {
    ['p-price', 'p-stock'].forEach((fieldId) => {
      const el = document.getElementById(fieldId);
      if (!el) return;
      el.readOnly = true;
      el.title = 'Only an admin can change this';
      el.style.background = '#f1f5f9';
    });
  }

  // Resize the chosen file into a thumbnail and a full-size picture.
  window.handleImageUpload = async function(event) {
    const file = event.target.files[0];
    if (!file) return;

    try {
      const [thumb, full] = await Promise.all([
        fileToDataUrl(file, THUMB_OPTIONS),
        fileToDataUrl(file, FULL_OPTIONS)
      ]);
      newImages = { thumb, full };
      showPreview(thumb);
    } catch (err) {
      newImages = null;
      event.target.value = '';
      notify(err.message);
    }
  };

  // Resize multiple chosen files into thumbnails + full images for the gallery.
  window.handleGalleryUpload = async function(event) {
    const files = Array.from(event.target.files || []);
    if (files.length === 0) return;

    try {
      const processed = await Promise.all(files.map(async (file) => {
        const [thumb, full] = await Promise.all([
          fileToDataUrl(file, THUMB_OPTIONS),
          fileToDataUrl(file, FULL_OPTIONS)
        ]);
        return { thumb, full };
      }));
      newGalleryImages = [...newGalleryImages, ...processed];
      showGalleryPreview();
      event.target.value = '';
    } catch (err) {
      console.error('Gallery upload failed:', err);
      notify('Could not process gallery images. Please try again.');
    }
  };

  // Bind Form Submission
  const productForm = document.getElementById('product-form');
  if (productForm) {
    productForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const id = document.getElementById('product-id').value;

      // The price must be saved as a number: the database rules compare it
      // with the price on every order, and cannot read text such as "3500.00".
      const price = Math.round(parseFloat(document.getElementById('p-price').value) * 100) / 100;
      if (!Number.isFinite(price) || price < 0) {
        notify('Enter a valid price.');
        return;
      }

      const name = document.getElementById('p-name').value.trim();
      const description = document.getElementById('p-desc').value.trim();
      if (name.length > 100) {
        notify('Product name must be 100 characters or less.');
        return;
      }
      if (description.length > 2000) {
        notify('Description must be 2000 characters or less.');
        return;
      }

      const productData = {
        productName: name,
        category: document.getElementById('p-category').value,
        productPrice: price,
        productStock: parseInt(document.getElementById('p-stock').value, 10) || 0,
        productDescription: description
      };

      // Parse variant rows into variantOptions array
      // Every variant sells at the product's price: the database rules only
      // accept an order line priced exactly like the product, so a per-variant
      // price could never be ordered.
      const variantOptions = [];
      const variantRows = document.querySelectorAll('#variant-list .variant-row');
      variantRows.forEach((row) => {
        const label = row.querySelector('[id^="v-label-"]')?.value.trim();
        const stock = parseInt(row.querySelector('[id^="v-stock-"]')?.value) || 0;
        const sku = row.querySelector('[id^="v-sku-"]')?.value.trim();
        if (label) {
          variantOptions.push({ label, stock, sku });
        }
      });
      // null removes the variants of an existing product when every row was deleted.
      productData.variantOptions = variantOptions.length > 0 ? variantOptions : null;

      // Collect gallery image full URLs
      const imageUrls = newGalleryImages.map((img) => img.full);
      if (imageUrls.length > 0) {
        productData.imageUrls = imageUrls;
      }

      // One multi-path write, so a product and its pictures are saved together.
      const updates = {};
      if (id) {
        Object.entries(productData).forEach(([key, value]) => {
          updates[`products/${id}/${key}`] = value;
        });
        if (newImages) {
          updates[`products/${id}/imageUrl`] = newImages.thumb;
          updates[`productImages/${id}`] = newImages.full;
        }
        // Save each gallery image under productImages/{id}/gallery/[n]
        newGalleryImages.forEach((img, i) => {
          updates[`productImages/${id}/gallery/${i}`] = img.full;
        });
      } else {
        const newId = push(ref(db, 'products')).key;
        updates[`products/${newId}`] = { ...productData, imageUrl: newImages?.thumb || '' };
        if (newImages) updates[`productImages/${newId}`] = newImages.full;
        newGalleryImages.forEach((img, i) => {
          updates[`productImages/${newId}/gallery/${i}`] = img.full;
        });
      }

      if (isStaff()) {
        if (!id) {
          notify('Only an admin can add new products. Click Edit on a product to fix its details.');
          return;
        }
        ['productPrice', 'productStock', 'variantOptions'].forEach((key) => {
          delete updates[`products/${id}/${key}`];
        });
      }

      const oldPrice = id ? rawProductsData?.[id]?.productPrice : undefined;

      try {
        await update(ref(db), updates);

        const priceChanged = !isStaff() && id && parseFloat(oldPrice) > 0 &&
          parseFloat(productData.productPrice) !== parseFloat(oldPrice);
        if (priceChanged) {
          const notified = await notifyPriceChange(
            id, productData.productName, oldPrice, productData.productPrice
          );
          window.logAdminAction?.(
            'PRICE_CHANGED',
            `${productData.productName}: price changed, ${notified} wishlist customer(s) notified.`
          );
        }
        window.resetProductFormModule();
      } catch (err) {
        console.error('Failed to save product:', err);
        notify('Could not save the product. Please try again.');
      }
    });
  }
}

// ---- Variant rows ----
window.addVariantRow = function() {
  const list = document.getElementById('variant-list');
  if (!list) return;
  const idx = variantRowCount++;
  const row = document.createElement('div');
  row.className = 'variant-row';
  row.style.cssText = 'display:flex; gap:8px; align-items:center; margin-bottom:6px;';
  row.innerHTML = `
    <input type="text" id="v-label-${idx}" placeholder="e.g. Size: Large" style="flex:2; padding:6px; border-radius:6px; border:1px solid #cbd5e1; font-size:13px;">
    <input type="number" id="v-stock-${idx}" value="0" min="0" placeholder="0" style="flex:1; padding:6px; border-radius:6px; border:1px solid #cbd5e1; font-size:13px;">
    <input type="text" id="v-sku-${idx}" placeholder="SKU" style="flex:1; padding:6px; border-radius:6px; border:1px solid #cbd5e1; font-size:13px;">
    <button type="button" onclick="this.parentElement.remove()" style="background:#dc2626;color:#fff;border:none;padding:6px 10px;border-radius:6px;font-size:12px;">×</button>
  `;
  list.appendChild(row);
};

function showPreview(imageSrc) {
  const container = document.getElementById('image-preview-container');
  container.innerHTML = imageSrc
    ? `<img src="${imageSrc}" width="60" height="60" style="object-fit:cover; border-radius:6px; border:1px solid #cbd5e1;">`
    : '';
}

function showGalleryPreview() {
  const container = document.getElementById('gallery-preview-container');
  if (!container) return;
  if (newGalleryImages.length === 0) {
    container.innerHTML = '<span style="font-size:12px; color:#64748b;">No gallery images yet.</span>';
    return;
  }
  container.innerHTML = newGalleryImages.map((img, i) => `
    <div style="display:inline-block; margin:4px; position:relative;">
      <img src="${img.thumb}" width="60" height="60" style="object-fit:cover; border-radius:6px; border:1px solid #cbd5e1;">
      <button type="button" onclick="window.removeGalleryImage(${i})" style="position:absolute; top:-6px; right:-6px; background:#dc2626; color:#fff; border: none; border-radius:50%; width:20px; height:20px; font-size:10px; cursor:pointer;">×</button>
    </div>
  `).join('');
}

window.removeGalleryImage = function(index) {
  newGalleryImages.splice(index, 1);
  showGalleryPreview();
};

function getProductEntries() {
  return Array.isArray(rawProductsData)
    ? rawProductsData.map((prod, index) => [index, prod]).filter(([_, prod]) => prod !== null)
    : Object.entries(rawProductsData);
}

function renderProductsTable() {
  const tbody = document.getElementById('products-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('p-search-input')?.value || '').toLowerCase();
  const selectedCategory = document.getElementById('p-filter-category')?.value || 'ALL';

  let filtered = getProductEntries().filter(([_, prod]) => {
    if (!prod) return false;
    const name = (prod.productName || prod.name || '').toLowerCase();
    const cat = prod.category || prod.productCategory || 'Uncategorized';

    const matchesSearch = name.includes(searchQuery);
    const matchesCategory = selectedCategory === 'ALL' || cat === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:#64748b;">No matching products found.</td></tr>';
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
    const imageUrl = prod.imageUrl || prod.image || '';
    const variantCount = Array.isArray(prod.variantOptions) ? prod.variantOptions.length : 0;

    // Low stock warning badge
    const stockBadge = stock <= 5
      ? `<span class="badge badge-cancelled" style="font-weight:bold;">${stock} (Low)</span>`
      : `<span style="font-weight:600; color:#1e293b;">${stock}</span>`;

    const variantBadge = variantCount > 0
      ? `<span style="background:#fef3c7; color:#92400e; padding:2px 6px; border-radius:4px; font-size:10px; font-weight:600;">${variantCount} variant${variantCount > 1 ? 's' : ''}</span>`
      : '';

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>
        ${imageUrl ? `<img src="${escapeHtml(imageUrl)}" width="40" height="40" style="object-fit:cover; border-radius:6px;" alt="Product">` : '<div style="width:40px;height:40px;background:#e2e8f0;border-radius:6px;display:flex;align-items:center;justify-content:center;font-size:10px;color:#64748b;">No Img</div>'}
      </td>
      <td style="font-weight:600;">${escapeHtml(name)}</td>
      <td><span style="background:#e0f2fe; color:#0369a1; padding:3px 8px; border-radius:12px; font-size:11px; font-weight:600;">${escapeHtml(category)}</span></td>
      <td>₱${price.toFixed(2)}</td>
      <td>${stockBadge} ${variantBadge}</td>
      <td>
        <button class="btn btn-warning" onclick="window.editProductModule(${jsArg(id)})" aria-label="Edit product ${escapeHtml(name)}">Edit</button>
        ${isStaff() ? '' : `<button class="btn btn-danger" onclick="window.deleteProductModule(${jsArg(id)})" aria-label="Delete product ${escapeHtml(name)}">Delete</button>`}
      </td>
    `;
    fragment.appendChild(tr);
  });

  tbody.appendChild(fragment);
}

window.editProductModule = function(id) {
  const prod = rawProductsData[id];
  if (!prod) return;

  document.getElementById('product-id').value = id;
  document.getElementById('p-name').value = prod.productName || prod.name || '';
  document.getElementById('p-category').value = prod.category || prod.productCategory || '';

  let rawPrice = prod.productPrice ?? prod.price ?? 0;
  if (typeof rawPrice === 'string') rawPrice = rawPrice.replace(/[^0-9.-]+/g, "");
  document.getElementById('p-price').value = parseFloat(rawPrice) || 0;
  document.getElementById('p-stock').value = prod.productStock ?? prod.stock ?? 0;
  document.getElementById('p-desc').value = prod.productDescription || prod.description || '';

  // Load variants
  const variantList = document.getElementById('variant-list');
  if (variantList) {
    variantList.innerHTML = '';
    variantRowCount = 0;
    const variants = prod.variantOptions || [];
    variants.forEach((v) => {
      const idx = variantRowCount++;
      const row = document.createElement('div');
      row.className = 'variant-row';
      row.style.cssText = 'display:flex; gap:8px; align-items:center; margin-bottom:6px;';
      row.innerHTML = `
        <input type="text" id="v-label-${idx}" value="${escapeHtml(v.label || '')}" placeholder="e.g. Size: Large" style="flex:2; padding:6px; border-radius:6px; border:1px solid #cbd5e1; font-size:13px;">
        <input type="number" id="v-stock-${idx}" value="${v.stock ?? 0}" min="0" placeholder="0" style="flex:1; padding:6px; border-radius:6px; border:1px solid #cbd5e1; font-size:13px;">
        <input type="text" id="v-sku-${idx}" value="${escapeHtml(v.sku || '')}" placeholder="SKU" style="flex:1; padding:6px; border-radius:6px; border:1px solid #cbd5e1; font-size:13px;">
        <button type="button" onclick="this.parentElement.remove()" style="background:#dc2626;color:#fff;border:none;padding:6px 10px;border-radius:6px;font-size:12px;">×</button>
      `;
      variantList.appendChild(row);
    });
  }

  // The picture is only replaced when a new file is chosen.
  newImages = null;
  newGalleryImages = [];
  document.getElementById('p-image-file').value = '';
  showPreview(prod.imageUrl || prod.image || '');

  // Load existing gallery images
  const galleryList = prod.imageUrls || [];
  newGalleryImages = galleryList.map((url) => ({ thumb: url, full: url }));
  showGalleryPreview();

  document.getElementById('form-title').innerText = 'Edit Product';
  document.getElementById('save-btn').innerText = 'Update Product';
  document.getElementById('cancel-btn').style.display = 'inline-block';
};

window.resetProductFormModule = function() {
  document.getElementById('product-form').reset();
  document.getElementById('product-id').value = '';
  showPreview('');
  newImages = null;
  newGalleryImages = [];
  showGalleryPreview();
  variantRowCount = 0;
  const variantList = document.getElementById('variant-list');
  if (variantList) variantList.innerHTML = '';
  document.getElementById('form-title').innerText = 'Add New Product';
  document.getElementById('save-btn').innerText = 'Save Product';
  document.getElementById('cancel-btn').style.display = 'none';
};

window.deleteProductModule = async function(id) {
  if (isStaff()) return;
  if (!confirm('Are you sure you want to delete this item?')) return;

  try {
    await update(ref(db), { [`products/${id}`]: null, [`productImages/${id}`]: null });
  } catch (err) {
    console.error('Failed to delete product:', err);
    notify('Could not delete the product. Please try again.');
  }
};

// ---- One-time conversion of products saved before the thumbnail split ----

function setupImageConverter() {
  const table = document.getElementById('products-table-body')?.closest('table');
  if (!table || document.getElementById('image-convert-bar')) return;

  const bar = document.createElement('div');
  bar.id = 'image-convert-bar';
  bar.className = 'admin-only';
  bar.style.cssText = 'display:flex; align-items:center; gap:12px; margin-bottom:12px; font-size:13px; color:#475569;';
  bar.innerHTML = `
    <button type="button" class="btn btn-secondary" id="convert-images-btn">Convert existing images</button>
    <span id="convert-images-status"></span>
  `;
  table.before(bar);

  document.getElementById('convert-images-btn').addEventListener('click', convertExistingImages);
}

async function convertExistingImages() {
  if (isStaff()) return;
  const button = document.getElementById('convert-images-btn');
  const status = document.getElementById('convert-images-status');

  const todo = getProductEntries().filter(([_, prod]) =>
    prod && typeof prod.imageUrl === 'string' &&
    prod.imageUrl.startsWith('data:') && prod.imageUrl.length > BIG_IMAGE_CHARS
  );

  if (todo.length === 0) {
    status.textContent = 'Nothing to convert. All product images are already small.';
    return;
  }
  if (!confirm(`Convert ${todo.length} product image(s)? Each one gets a small thumbnail plus a resized full picture.`)) {
    return;
  }

  button.disabled = true;
  let converted = 0;
  let failed = 0;

  for (const [id, prod] of todo) {
    status.textContent = `Converting ${converted + failed + 1} of ${todo.length}...`;
    try {
      const [thumb, full] = await Promise.all([
        resizeDataUrl(prod.imageUrl, THUMB_OPTIONS),
        resizeDataUrl(prod.imageUrl, FULL_OPTIONS)
      ]);
      await update(ref(db), {
        [`products/${id}/imageUrl`]: thumb,
        [`productImages/${id}`]: full
      });
      converted++;
    } catch (err) {
      console.error(`Could not convert the image of product ${id}:`, err);
      failed++;
    }
  }

  button.disabled = false;
  status.textContent = `Done: ${converted} converted` + (failed ? `, ${failed} failed (see the browser console).` : '.');
}

// ---- Repair product data ---------------------------------------------------
// The customer app and the database rules need `productPrice` and
// `productStock` to be real numbers. Products saved by older versions may
// hold them as text ("24000") or under the old keys `price` / `stock`.
// This converts them in one go.

function toCleanNumber(value, { integer = false } = {}) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value !== 'string') return null;
  const cleaned = value.replace(/[^0-9.\-]/g, '');
  if (cleaned === '' || cleaned === '-' || cleaned === '.') return null;
  const n = integer ? parseInt(cleaned, 10) : parseFloat(cleaned);
  return Number.isFinite(n) ? n : null;
}

function findProductsToRepair() {
  const entries = Array.isArray(rawProductsData)
    ? rawProductsData.map((prod, index) => [String(index), prod])
    : Object.entries(rawProductsData || {});
  const updates = {};
  const names = [];

  entries.forEach(([id, prod]) => {
    if (!prod || typeof prod !== 'object') return;
    let touched = false;

    if (typeof prod.productPrice !== 'number') {
      const price = toCleanNumber(prod.productPrice ?? prod.price);
      if (price !== null && price >= 0) {
        updates[`products/${id}/productPrice`] = Math.round(price * 100) / 100;
        touched = true;
      }
    }
    if (typeof prod.productStock !== 'number') {
      // A product with no readable stock is set to 0 (out of stock), which is
      // the safe choice; the admin can raise it afterwards.
      const stock = toCleanNumber(prod.productStock ?? prod.stock, { integer: true });
      updates[`products/${id}/productStock`] = stock !== null && stock >= 0 ? stock : 0;
      touched = true;
    }
    if (touched) names.push(prod.productName || prod.name || id);
  });

  return { updates, names };
}

window.repairProductData = async function() {
  if (isStaff()) return;
  const { updates, names } = findProductsToRepair();
  if (names.length === 0) {
    notify('All products already have a numeric price and stock.', 'success');
    return;
  }
  const preview = names.slice(0, 8).join('\n- ');
  const more = names.length > 8 ? `\n...and ${names.length - 8} more` : '';
  if (!confirm(`Fix price/stock format on ${names.length} product(s)?\n\n- ${preview}${more}\n\nProducts with no readable stock will be set to 0.`)) {
    return;
  }
  try {
    await update(ref(db), updates);
    notify(`Fixed ${names.length} product(s). Customers can now order them.`, 'success');
    window.logAdminAction?.('Product Data Repair', `Converted price/stock to numbers on ${names.length} product(s)`);
  } catch (err) {
    console.error('Repair failed:', err);
    notify('Failed to fix product data. Check your connection and admin access.', 'error');
  }
};
