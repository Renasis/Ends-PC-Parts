import { ref, push, onValue } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { auth, db } from "./firebase-config.js";
import { escapeHtml } from "./html-utils.js";

let rawLogsCache = {};

export function initLogsModule() {
  const logsRef = ref(db, 'adminLogs');

  onValue(logsRef, (snapshot) => {
    rawLogsCache = snapshot.val() || {};
    renderLogsTable();
    window.hideLoading('logs');
  });

  document.getElementById('logs-search-input')?.addEventListener('input', renderLogsTable);
}

window.logAdminAction = async function(actionType, description) {
  const logsRef = ref(db, 'adminLogs');
  try {
    await push(logsRef, {
      actionType: actionType,
      description: description,
      // Who did it, so the log still makes sense with several people signed in.
      actor: auth.currentUser?.email || '',
      actorRole: document.body.classList.contains('role-staff') ? 'staff' : 'admin',
      timestamp: Date.now()
    });
  } catch (err) {
    console.error("Failed to write activity log:", err);
  }
};

function renderLogsTable() {
  const tbody = document.getElementById('logs-table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const searchQuery = (document.getElementById('logs-search-input')?.value || '').toLowerCase();
  
  if (!rawLogsCache || Object.keys(rawLogsCache).length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; color:#64748b;">No activity logs recorded yet.</td></tr>';
    return;
  }

  let logsList = Object.entries(rawLogsCache).map(([id, log]) => ({ id, ...log }));
  logsList.sort((a, b) => b.timestamp - a.timestamp);

  let filtered = logsList.filter(log => {
    return (log.actionType || '').toLowerCase().includes(searchQuery) ||
           (log.description || '').toLowerCase().includes(searchQuery);
  });

  if (filtered.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" style="text-align:center; color:#64748b;">No matching logs found.</td></tr>';
    return;
  }

  const fragment = document.createDocumentFragment();

  filtered.forEach(log => {
    const dateStr = log.timestamp ? new Date(log.timestamp).toLocaleString() : 'N/A';
    const type = log.actionType || 'INFO';

    let badgeColor = 'background: #e0f2fe; color: #0369a1;';
    if (type.includes('DELETE') || type.includes('CANCEL')) badgeColor = 'background: #fee2e2; color: #991b1b;';
    else if (type.includes('CREATE') || type.includes('APPROVE')) badgeColor = 'background: #dcfce7; color: #166534;';

    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td style="color: #64748b; font-size: 13px;">${escapeHtml(dateStr)}</td>
      <td><span style="${badgeColor} padding: 3px 8px; border-radius: 12px; font-size: 11px; font-weight: 600;">${escapeHtml(type)}</span></td>
      <td style="color: #1e293b;">${escapeHtml(log.description || 'N/A')}${log.actor ? `<div style="font-size:12px; color:#64748b;">by ${escapeHtml(log.actor)}${log.actorRole === 'staff' ? ' (staff)' : ''}</div>` : ''}</td>
    `;
    fragment.appendChild(tr);
  });

  tbody.appendChild(fragment);
}