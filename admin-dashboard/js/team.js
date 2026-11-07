import { initializeApp, deleteApp } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js";
import {
  getAuth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
  signOut as signOutOf
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";
import { ref, onValue, get, update } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { auth, db, firebaseConfig } from "./firebase-config.js";
import { escapeHtml } from "./html-utils.js";
import { ROLE_LABELS } from "./permissions.js";

// Team tab (admins only): create sign-in accounts for admins and staff.
//
// Database layout (see database.rules.json):
//   admins/{uid}  true            admin access (checked by the rules)
//   staff/{uid}   true            staff access (checked by the rules)
//   team/{uid}    {name, email, role, createdAt, createdBy}   what this tab lists
//
// There are no Cloud Functions, so the Firebase account is created from the
// browser with a second, temporary app instance. That keeps the admin signed
// in; creating it with the normal app would sign the admin out.

const CREATE_ERRORS = {
  'auth/invalid-email': 'Enter a valid email address.',
  'auth/weak-password': 'Choose a stronger password (at least 8 characters).',
  'auth/network-request-failed': 'No connection. Check your internet and try again.',
  'auth/operation-not-allowed': 'Email/password sign-in is turned off in the Firebase console.'
};

let team = {};

function $(id) {
  return document.getElementById(id);
}

function setStatus(message, isError = false) {
  const el = $('team-status');
  el.textContent = message;
  el.style.color = isError ? '#dc2626' : '#166534';
}

function formatDate(ms) {
  return ms ? new Date(ms).toLocaleDateString() : '';
}

export function initTeamModule() {
  const body = $('team-table-body');
  const showRow = (html, color) => {
    body.innerHTML = `<tr><td colspan="5" style="text-align:center; color:${color};">${html}</td></tr>`;
  };
  console.info('[team] module started for', auth.currentUser?.email);

  // If the database never answers, say so instead of "Loading..." forever.
  const stall = setTimeout(() => {
    console.warn('[team] no answer from the database after 8 seconds');
    showRow('Still loading the team. Check your connection, then reload the page.', '#b45309');
  }, 8000);

  onValue(ref(db, 'team'), (snapshot) => {
    clearTimeout(stall);
    team = snapshot.val() || {};
    console.info('[team] loaded', Object.keys(team).length, 'member(s)');
    try {
      renderTeam();
    } catch (err) {
      console.error('[team] could not draw the table:', err);
      showRow(`Could not show the team (${escapeHtml(err.message)}).`, '#dc2626');
    }
    window.hideLoading('team');
  }, (err) => {
    clearTimeout(stall);
    console.error('[team] failed to load:', err);
    showRow(`Could not load the team (${escapeHtml(err.code || err.message)}).`, '#dc2626');
    window.hideLoading('team');
  });

  $('team-form').addEventListener('submit', handleCreate);
  $('team-table-body').addEventListener('click', handleTableClick);
}

// ------------------------------------------------------------------ create

async function handleCreate(event) {
  event.preventDefault();
  const name = $('team-name').value.trim();
  const email = $('team-email').value.trim().toLowerCase();
  const password = $('team-password').value;
  const role = $('team-role').value;
  const button = $('team-submit');

  if (!name) return setStatus('Enter the person\'s name.', true);
  if (password.length < 8) return setStatus('The password must have at least 8 characters.', true);
  if (!ROLE_LABELS[role]) return setStatus('Choose a role.', true);

  button.disabled = true;
  setStatus('Creating the account...');

  try {
    const uid = await createAuthAccount(email, password);
    await grantRole(uid, { name, email, role });
    $('team-form').reset();
    setStatus(`${ROLE_LABELS[role]} account created for ${email}.`);
    window.logAdminAction?.('TEAM_MEMBER_ADDED', `${ROLE_LABELS[role]} account created for ${email}.`);
  } catch (err) {
    if (err.code === 'auth/email-already-in-use') {
      await handleExistingAccount({ name, email, password, role });
    } else {
      console.error('Failed to create the account:', err);
      setStatus(CREATE_ERRORS[err.code] || 'Could not create the account. Please try again.', true);
    }
  } finally {
    button.disabled = false;
  }
}

// Creates the Firebase account and returns its uid, without touching the
// admin's own sign-in.
async function createAuthAccount(email, password) {
  const helper = initializeApp(firebaseConfig, `team-helper-${Date.now()}`);
  try {
    const helperAuth = getAuth(helper);
    const credential = await createUserWithEmailAndPassword(helperAuth, email, password);
    const uid = credential.user.uid;
    await signOutOf(helperAuth);
    return uid;
  } finally {
    await deleteApp(helper);
  }
}

// The email already has an account (a customer, or an earlier attempt that
// did not finish). Offer to give that account the role instead.
async function handleExistingAccount({ name, email, password, role }) {
  const uid = await findExistingUid(email, password);
  if (!uid) {
    setStatus('That email already has an account and it could not be found in the customer list. Use a different email.', true);
    return;
  }
  if (team[uid]) {
    setStatus('This person is already on the team.', true);
    return;
  }

  const ok = confirm(
    `${email} already has an account. Give it ${ROLE_LABELS[role]} access?\n\n` +
    'It keeps its current password; the password you typed is not used.'
  );
  if (!ok) {
    setStatus('Nothing was changed.');
    return;
  }

  try {
    await grantRole(uid, { name, email, role });
    $('team-form').reset();
    setStatus(`${email} now has ${ROLE_LABELS[role]} access.`);
    window.logAdminAction?.('TEAM_MEMBER_ADDED', `${ROLE_LABELS[role]} access given to existing account ${email}.`);
  } catch (err) {
    console.error('Failed to give access:', err);
    setStatus('Could not save the access. Please try again.', true);
  }
}

// Finds the uid of an existing account: first from the customer list, then,
// for an account made by an unfinished attempt, by signing in with the
// password that was just typed.
async function findExistingUid(email, password) {
  try {
    const users = (await get(ref(db, 'users'))).val() || {};
    const match = Object.entries(users).find(([, u]) => (u?.email || '').toLowerCase() === email);
    if (match) return match[0];
  } catch (err) {
    console.warn('Could not search the customer list:', err);
  }

  const helper = initializeApp(firebaseConfig, `team-helper-${Date.now()}`);
  try {
    const helperAuth = getAuth(helper);
    const credential = await signInWithEmailAndPassword(helperAuth, email, password);
    const uid = credential.user.uid;
    await signOutOf(helperAuth);
    return uid;
  } catch {
    return null;
  } finally {
    await deleteApp(helper);
  }
}

// One atomic write: the access flag the rules check, and the Team entry.
function grantRole(uid, { name, email, role }) {
  return update(ref(db), {
    [`admins/${uid}`]: role === 'admin' ? true : null,
    [`staff/${uid}`]: role === 'staff' ? true : null,
    [`team/${uid}`]: {
      name,
      email,
      role,
      createdAt: Date.now(),
      createdBy: auth.currentUser?.email || 'admin'
    }
  });
}

// ------------------------------------------------------------------ table

function renderTeam() {
  const tbody = $('team-table-body');
  const myUid = auth.currentUser?.uid;
  const entries = Object.entries(team)
    .filter(([, m]) => m && typeof m === 'object')
    .sort(([, a], [, b]) => (a.createdAt || 0) - (b.createdAt || 0));

  if (entries.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#64748b;">No team members yet.</td></tr>';
    return;
  }

  tbody.innerHTML = entries.map(([uid, m]) => {
    const isMe = uid === myUid;
    const role = m.role === 'staff' ? 'staff' : 'admin';
    const otherRole = role === 'admin' ? 'staff' : 'admin';
    const actions = isMe
      ? '<span style="color:#64748b; font-size:12px;">This is you</span>'
      : `
        <button class="btn btn-secondary" style="padding:4px 10px; font-size:12px;" data-action="role" data-uid="${escapeHtml(uid)}" data-role="${otherRole}">Make ${ROLE_LABELS[otherRole]}</button>
        <button class="btn btn-secondary" style="padding:4px 10px; font-size:12px;" data-action="reset" data-uid="${escapeHtml(uid)}">Reset password</button>
        <button class="btn btn-danger" style="padding:4px 10px; font-size:12px;" data-action="remove" data-uid="${escapeHtml(uid)}">Remove access</button>`;

    return `
      <tr>
        <td style="font-weight:600; color:#1e293b;">${escapeHtml(m.name || '')}</td>
        <td>${escapeHtml(m.email || '')}</td>
        <td><span class="role-pill ${role}">${ROLE_LABELS[role]}</span></td>
        <td style="font-size:12px; color:#64748b;">${escapeHtml(formatDate(m.createdAt))}${m.createdBy && m.createdBy !== 'self' ? `<br>by ${escapeHtml(m.createdBy)}` : ''}</td>
        <td>${actions}</td>
      </tr>`;
  }).join('');
}

function handleTableClick(event) {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const { action, uid, role } = button.dataset;
  if (action === 'remove') removeAccess(uid);
  if (action === 'role') changeRole(uid, role);
  if (action === 'reset') resetPassword(uid);
}

async function removeAccess(uid) {
  const member = team[uid];
  if (!member || uid === auth.currentUser?.uid) return;

  const admins = Object.values(team).filter((m) => m?.role === 'admin').length;
  if (member.role === 'admin' && admins <= 1) {
    setStatus('You cannot remove the last admin.', true);
    return;
  }
  if (!confirm(`Remove dashboard access for ${member.email}? Their sign-in account stays, but it can no longer open this dashboard.`)) return;

  try {
    await update(ref(db), { [`admins/${uid}`]: null, [`staff/${uid}`]: null, [`team/${uid}`]: null });
    setStatus(`${member.email} no longer has access.`);
    window.logAdminAction?.('TEAM_MEMBER_REMOVED', `Dashboard access removed for ${member.email}.`);
  } catch (err) {
    console.error('Failed to remove access:', err);
    setStatus('Could not remove the access. Please try again.', true);
  }
}

async function changeRole(uid, newRole) {
  const member = team[uid];
  if (!member || uid === auth.currentUser?.uid || !ROLE_LABELS[newRole]) return;

  if (!confirm(`Make ${member.email} ${ROLE_LABELS[newRole]}?`)) return;
  try {
    await update(ref(db), {
      [`admins/${uid}`]: newRole === 'admin' ? true : null,
      [`staff/${uid}`]: newRole === 'staff' ? true : null,
      [`team/${uid}/role`]: newRole
    });
    setStatus(`${member.email} is now ${ROLE_LABELS[newRole]}.`);
    window.logAdminAction?.('TEAM_ROLE_CHANGED', `${member.email} changed to ${ROLE_LABELS[newRole]}.`);
  } catch (err) {
    console.error('Failed to change the role:', err);
    setStatus('Could not change the role. Please try again.', true);
  }
}

async function resetPassword(uid) {
  const member = team[uid];
  if (!member?.email) return;
  if (!confirm(`Send a password reset email to ${member.email}?`)) return;
  try {
    await sendPasswordResetEmail(auth, member.email);
    setStatus(`Password reset email sent to ${member.email}.`);
  } catch (err) {
    console.error('Failed to send the reset email:', err);
    setStatus('Could not send the reset email. Please try again.', true);
  }
}