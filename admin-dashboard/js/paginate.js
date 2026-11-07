// Adds simple pagination to existing tables without touching the modules
// that fill them. Each module keeps rebuilding its <tbody> as before; this
// watches for that and shows only the current page of rows.
//
// Orders is intentionally not paginated: its "select all" checkbox would
// also select rows hidden on other pages.

const PAGE_SIZE = 15;
const TABLES = [
  'products-table-body',
  'returns-table-body',
  'inventory-table-body',
  'customers-table-body',
  'reviews-table-body',
  'verification-table-body',
  'reports-table-body',
  'logs-table-body'
];

function attach(tbodyId) {
  const tbody = document.getElementById(tbodyId);
  if (!tbody || tbody.dataset.paginated) return;
  tbody.dataset.paginated = 'true';

  const table = tbody.closest('table');
  const pager = document.createElement('div');
  pager.className = 'pager';
  pager.hidden = true;
  table.insertAdjacentElement('afterend', pager);

  let page = 1;
  let applying = false;

  function apply() {
    applying = true;
    const rows = Array.from(tbody.children);
    // A single "No matching ..." row is not data; leave it alone.
    const isEmptyState = rows.length === 1 && rows[0].children.length === 1;
    const pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
    page = Math.min(page, pages);
    const start = (page - 1) * PAGE_SIZE;

    rows.forEach((row, i) => {
      row.hidden = !isEmptyState && (i < start || i >= start + PAGE_SIZE);
    });

    if (isEmptyState || rows.length <= PAGE_SIZE) {
      pager.hidden = true;
    } else {
      pager.hidden = false;
      pager.innerHTML = '';
      const info = document.createElement('span');
      info.textContent = `${start + 1}\u2013${Math.min(start + PAGE_SIZE, rows.length)} of ${rows.length}`;

      const prev = document.createElement('button');
      prev.type = 'button';
      prev.className = 'btn btn-secondary btn-sm';
      prev.textContent = 'Previous';
      prev.disabled = page === 1;
      prev.addEventListener('click', () => { page--; apply(); });

      const next = document.createElement('button');
      next.type = 'button';
      next.className = 'btn btn-secondary btn-sm';
      next.textContent = 'Next';
      next.disabled = page === pages;
      next.addEventListener('click', () => { page++; apply(); });

      pager.append(prev, info, next);
    }
    // Let the observer's own callback for these changes pass.
    setTimeout(() => { applying = false; }, 0);
  }

  // Re-apply whenever the module re-renders the rows (including live updates).
  new MutationObserver(() => { if (!applying) apply(); })
    .observe(tbody, { childList: true });

  // Typing in search or changing a filter starts again from page 1.
  const tab = tbody.closest('.tab-content');
  const restart = () => { page = 1; };
  tab?.addEventListener('input', restart);
  tab?.addEventListener('change', restart);

  apply();
}

export function initPagination() {
  TABLES.forEach(attach);
}
