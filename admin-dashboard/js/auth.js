import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";
import { ref, get, set } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { auth, db } from "./firebase-config.js";
import { ROLE_LABELS } from "./permissions.js";

// Dashboard access = signed in AND one of these is true in the database:
//   admins/{uid}   admin, full access
//   staff/{uid}    staff, only the tabs in permissions.js
// The same lists are checked by database.rules.json, so the dashboard cannot
// be used to write data even if someone bypasses this screen.

const LOGIN_ERRORS = {
  'auth/invalid-credential': 'Wrong email or password.',
  'auth/invalid-email': 'Enter a valid email address.',
  'auth/user-disabled': 'This account has been disabled.',
  'auth/too-many-requests': 'Too many attempts. Wait a moment and try again.',
  'auth/network-request-failed': 'No connection. Check your internet and try again.'
};

const NOT_ADMIN_MESSAGE = 'This account does not have dashboard access.';
const VERIFY_FAILED_MESSAGE = 'Could not verify admin access. Check your connection and try again.';

function $(id) {
  return document.getElementById(id);
}

function showLoading() {
  $('auth-loading').hidden = false;
  $('login-form').hidden = true;
}

function showLogin(message = '') {
  $('auth-loading').hidden = true;
  $('login-form').hidden = false;
  $('login-error').textContent = message;
  $('login-submit').disabled = false;
  $('login-submit').textContent = 'Sign in';
}

function showDashboard(email, role) {
  document.body.classList.remove('auth-locked');
  document.body.classList.remove('role-admin', 'role-staff');
  document.body.classList.add(`role-${role}`);
  $('auth-screen').hidden = true;
  $('admin-email').textContent = email;
  const pill = $('admin-role');
  pill.textContent = ROLE_LABELS[role] || role;
  pill.className = `role-pill ${role}`;
}

/** 'admin', 'staff', or null when the account has no dashboard access. */
async function getRole(uid) {
  if ((await get(ref(db, `admins/${uid}`))).val() === true) return 'admin';
  if ((await get(ref(db, `staff/${uid}`))).val() === true) return 'staff';
  return null;
}

// Admins added by hand in the Firebase console have no Team entry yet, so
// create it the first time they sign in. Staff entries are made by an admin.
async function ensureTeamEntry(user, role) {
  if (role !== 'admin') return;
  try {
    const entryRef = ref(db, `team/${user.uid}`);
    if ((await get(entryRef)).exists()) return;
    const email = user.email || '';
    await set(entryRef, {
      name: user.displayName || email.split('@')[0] || 'Admin',
      email,
      role: 'admin',
      createdAt: Date.now(),
      createdBy: 'self'
    });
  } catch (err) {
    console.warn('Could not save the Team entry:', err);
  }
}

/**
 * Shows the login screen until an admin or staff member is signed in, then
 * calls [onAdminReady] with their role ('admin' or 'staff') once. Signing out reloads the page so every live
 * database listener is dropped.
 */
export function initAuthGate(onAdminReady) {
  let started = false;
  let lastError = '';

  $('login-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    lastError = '';
    $('login-error').textContent = '';
    $('login-submit').disabled = true;
    $('login-submit').textContent = 'Signing in...';

    try {
      await signInWithEmailAndPassword(
        auth,
        $('login-email').value.trim(),
        $('login-password').value
      );
      // onAuthStateChanged takes it from here.
    } catch (err) {
      showLogin(LOGIN_ERRORS[err.code] || 'Could not sign in. Please try again.');
    }
  });

  $('logout-btn').addEventListener('click', async () => {
    await signOut(auth);
    window.location.reload();
  });

  onAuthStateChanged(auth, async (user) => {
    if (!user) {
      showLogin(lastError);
      return;
    }

    showLoading();
    try {
      const role = await getRole(user.uid);
      if (role) {
        showDashboard(user.email || '', role);
        if (!started) {
          started = true;
          await ensureTeamEntry(user, role);
          onAdminReady(role);
        }
        return;
      }
      lastError = NOT_ADMIN_MESSAGE;
    } catch (err) {
      console.error('Admin check failed:', err);
      lastError = VERIFY_FAILED_MESSAGE;
    }

    await signOut(auth); // triggers this callback again with user = null
  });
}