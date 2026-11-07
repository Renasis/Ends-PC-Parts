import { initProductsModule } from './products.js';
import { initOrdersModule } from './orders.js';
import { initReturnsModule } from './returns.js';
import { initAnalyticsModule } from './analytics.js';
import { initInventoryModule } from './inventory.js';
import { initCustomersModule } from './customers.js';
import { initChatsModule } from './chats.js';
import { initReviewsModule } from './reviews.js';
import { initSettingsModule } from './settings.js';
import { initVerificationModule } from './verification.js';
import { initPromosModule } from './promos.js';
import { initReportsModule } from './reports.js';
import { initLogsModule } from './logs.js';
import { initNewOrderAlerts } from './new-orders.js';
import { initTeamModule } from './team.js';
import { initStaffHome } from './staff-home.js';
import { initAuthGate } from './auth.js';
import { canOpenTab, STAFF_TABS } from './permissions.js';

import './toast.js';
import './password-toggle.js';
import { initPagination } from './paginate.js';

// ---- Navigation -----------------------------------------------------------
const DEFAULT_TAB = 'dashboard';

// Set once someone signs in. Until then every tab is allowed (nothing is
// visible behind the sign-in screen anyway).
let currentRole = null;

// Hides the menu items (and group headings left empty) a role cannot open.
function applyRole(role) {
  currentRole = role;
  navButtons().forEach((btn) => { btn.hidden = !canOpenTab(role, btn.dataset.tab); });

  document.querySelectorAll('.menu-group').forEach((heading) => {
    let next = heading.nextElementSibling;
    let anyVisible = false;
    while (next && !next.classList.contains('menu-group')) {
      if (next.matches('.menu-item') && !next.hidden) anyVisible = true;
      next = next.nextElementSibling;
    }
    heading.hidden = !anyVisible;
  });
}

function navButtons() {
  return document.querySelectorAll('.menu-item[data-tab]');
}

function setNavOpen(open) {
  document.body.classList.toggle('nav-open', open);
  const toggle = document.getElementById('menu-toggle');
  if (toggle) toggle.setAttribute('aria-expanded', String(open));
}

// Global tab switcher (kept on window because index.html buttons call it).
// The second argument is optional and ignored: the nav button is found by data-tab.
window.switchTab = function(tabName) {
  if (currentRole && !canOpenTab(currentRole, tabName)) return;
  const targetTab = document.getElementById(`${tabName}-tab`);
  if (!targetTab) return;

  document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
  targetTab.classList.add('active');

  navButtons().forEach(btn => {
    const isActive = btn.dataset.tab === tabName;
    btn.classList.toggle('active', isActive);
    if (isActive) {
      btn.setAttribute('aria-current', 'page');
      document.title = `${btn.textContent.trim()} - PC Parts Admin`;
    } else {
      btn.removeAttribute('aria-current');
    }
  });

  // Remember the tab so a refresh (or a shared link) lands on the same page.
  if (location.hash !== `#${tabName}`) history.replaceState(null, '', `#${tabName}`);
  document.getElementById('main-content')?.scrollTo({ top: 0 });
  setNavOpen(false);
};

function initNavigation() {
  navButtons().forEach(btn => {
    btn.addEventListener('click', () => window.switchTab(btn.dataset.tab));
  });

  document.getElementById('menu-toggle')?.addEventListener('click', () => {
    setNavOpen(!document.body.classList.contains('nav-open'));
  });
  document.getElementById('sidebar-backdrop')?.addEventListener('click', () => setNavOpen(false));

  window.addEventListener('hashchange', () => {
    const tab = location.hash.slice(1);
    if (tab) window.switchTab(tab);
  });

  // Escape closes the sidebar (mobile) and the top-most open modal.
  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (document.body.classList.contains('nav-open')) {
      setNavOpen(false);
      return;
    }
    const openModals = document.querySelectorAll('.modal.active');
    if (openModals.length) openModals[openModals.length - 1].classList.remove('active');
  });

  // Clicking the dark backdrop (not the card) also closes a modal.
  document.addEventListener('mousedown', (event) => {
    if (event.target.classList?.contains('modal') && event.target.classList.contains('active')) {
      event.target.classList.remove('active');
    }
  });

  const initial = location.hash.slice(1);
  window.switchTab(document.getElementById(`${initial}-tab`) ? initial : DEFAULT_TAB);
}

// Global loading state for dashboard modules
const loadingModules = new Set([
  'analytics','products','orders','returns','inventory','customers',
  'chats','reviews','settings','verification','promos','reports','logs','team','staff-home'
]);

window.hideLoading = function(moduleName) {
  loadingModules.delete(moduleName);
  const overlay = document.getElementById('dashboard-loading');
  if (overlay && loadingModules.size === 0) {
    overlay.style.display = 'none';
  }
};

function startDashboard(role) {
  applyRole(role);
  // Staff land on Orders; a link to a tab they cannot open falls back there too.
  const current = location.hash.slice(1) || DEFAULT_TAB;
  if (!canOpenTab(role, current)) window.switchTab(STAFF_TABS[0]);
  else window.switchTab(current);

  // Show loading overlay now that admin is authenticated
  const overlay = document.getElementById('dashboard-loading');
  if (overlay) overlay.style.display = 'flex';

  // [name used by hideLoading, start function, allowed for staff, allowed for admin (default yes)]
  const modules = [
    ['analytics', initAnalyticsModule, false],
    ['products', initProductsModule, true],
    ['orders', initOrdersModule, true],
    ['returns', initReturnsModule, true],
    ['inventory', initInventoryModule, true],
    ['customers', initCustomersModule, true],
    ['chats', initChatsModule, true],
    ['reviews', initReviewsModule, true],
    ['settings', initSettingsModule, false],
    ['verification', initVerificationModule, true],
    ['promos', initPromosModule, false],
    ['reports', initReportsModule, false],
    ['logs', initLogsModule, false],
    ['team', initTeamModule, false],
    ['new-orders', initNewOrderAlerts, true],
    ['staff-home', initStaffHome, true, false], // staff overview only; admins keep the full Dashboard
  ];

  // Staff do not load the screens they cannot open: the database would refuse
  // those reads, and the loading overlay would wait for them.
  const initFns = [];
  modules.forEach(([name, fn, staffAllowed, adminAllowed = true]) => {
    const allowed = role === 'admin' ? adminAllowed : staffAllowed;
    if (allowed) initFns.push(fn);
    else window.hideLoading(name);
  });

  initPagination();

  initFns.forEach(fn => {
    try {
      fn();
    } catch (err) {
      console.error('Module init failed:', fn.name, err);
    }
  });

  // Fallback: hide loading overlay after 10 seconds even if a Firebase listener
  // never fires (e.g., rules block read or network issue)
  setTimeout(() => {
    const ov = document.getElementById('dashboard-loading');
    if (ov) ov.style.display = 'none';
  }, 10000);
}

// Nothing loads until an admin has signed in (see auth.js).
document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  initAuthGate(startDashboard);
});