import { notify } from "./toast.js";
import {
  ref, onValue, update, push, serverTimestamp, query, limitToLast
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db, auth } from "./firebase-config.js";
import { escapeHtml, jsArg } from "./html-utils.js";

// Data (shared with the mobile app):
//   chatThreads/{uid}          summary: customerName, lastMessage, lastTimestamp,
//                              lastFromAdmin, customerReadAt, adminReadAt
//   chats/{uid}/messages/{id}  the messages themselves
// The thread list only reads the small summaries; messages are loaded for the
// one conversation that is open.
const MESSAGE_LIMIT = 100;
const PREVIEW_LENGTH = 200;

let threads = {};
let activeUserId = null;
let activeMessages = [];
let stopMessages = null;

function isUnread(thread) {
  return thread.lastFromAdmin !== true && (thread.lastTimestamp || 0) > (thread.adminReadAt || 0);
}

function formatTime(ts) {
  if (!ts) return '';
  const date = new Date(ts);
  const sameDay = date.toDateString() === new Date().toDateString();
  return sameDay
    ? date.toLocaleTimeString('en-PH', { hour: 'numeric', minute: '2-digit' })
    : date.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' });
}

function chatsTabIsOpen() {
  return document.getElementById('chats-tab')?.classList.contains('active') === true;
}

export function initChatsModule() {
  onValue(ref(db, 'chatThreads'), (snapshot) => {
    threads = snapshot.val() || {};
    renderThreads();
    renderUnreadBadge();
    markActiveRead();
    window.hideLoading('chats');
  }, (err) => {
    console.error('Could not load chat threads:', err);
    notify('Could not load customer chats.');
    window.hideLoading('chats');
  });

  // Opening the Chats tab counts as reading the conversation that is selected.
  document.querySelector('.menu-item[data-tab="chats"]')?.addEventListener('click', markActiveRead);
  window.addEventListener('hashchange', markActiveRead);
}

function renderUnreadBadge() {
  const badge = document.getElementById('chats-unread-badge');
  if (!badge) return;
  const count = Object.values(threads).filter(isUnread).length;
  badge.textContent = count > 99 ? '99+' : String(count);
  badge.hidden = count === 0;
}

function renderThreads() {
  const container = document.getElementById('chat-threads-list');
  if (!container) return;

  const entries = Object.entries(threads)
    .sort(([, a], [, b]) => (b.lastTimestamp || 0) - (a.lastTimestamp || 0));

  if (entries.length === 0) {
    container.innerHTML = '<div style="padding: 20px; text-align: center; color: #64748b; font-size: 13px;">No customer chats yet. They appear here when a customer sends a message from the app.</div>';
    return;
  }

  container.innerHTML = entries.map(([userId, thread]) => {
    const unread = isUnread(thread);
    const selected = activeUserId === userId
      ? 'background: #e0f2fe; border-color: #0284c7;'
      : 'background: #ffffff; border-color: #e2e8f0;';
    const name = thread.customerName || `Customer (${userId.substring(0, 6)}...)`;
    const dot = unread
      ? '<span aria-label="Unread" style="width: 8px; height: 8px; border-radius: 50%; background: #2563eb; flex-shrink: 0;"></span>'
      : '';

    return `
      <div onclick="window.selectChatThread(${jsArg(userId)})" style="padding: 12px; border-radius: 8px; border: 1px solid; cursor: pointer; transition: all 0.2s; ${selected}">
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
          <div style="flex: 1; min-width: 0; font-weight: ${unread ? 700 : 600}; font-size: 13px; color: #1e293b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHtml(name)}</div>
          <div style="font-size: 11px; color: #64748b; flex-shrink: 0;">${escapeHtml(formatTime(thread.lastTimestamp))}</div>
          ${dot}
        </div>
        <div style="font-size: 12px; color: ${unread ? '#1e293b' : '#64748b'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${thread.lastFromAdmin ? 'You: ' : ''}${escapeHtml(thread.lastMessage || '')}</div>
      </div>
    `;
  }).join('');
}

window.selectChatThread = function(userId) {
  if (stopMessages) stopMessages();
  activeUserId = userId;
  activeMessages = [];

  const thread = threads[userId] || {};
  const headerEl = document.getElementById('chat-header');
  if (headerEl) headerEl.innerText = thread.customerName || `Customer (${userId.substring(0, 6)}...)`;
  renderThreads();
  renderMessages('Loading messages...');

  const latest = query(ref(db, `chats/${userId}/messages`), limitToLast(MESSAGE_LIMIT));
  stopMessages = onValue(latest, (snapshot) => {
    if (activeUserId !== userId) return;
    activeMessages = Object.entries(snapshot.val() || {})
      .filter(([, msg]) => msg && typeof msg === 'object')
      .sort(([, a], [, b]) => (a.timestamp || 0) - (b.timestamp || 0));
    renderMessages();
    markActiveRead();
  }, (err) => {
    console.error('Could not load chat messages:', err);
    renderMessages('Could not load this conversation.');
  });
};

function renderMessages(placeholder) {
  const container = document.getElementById('chat-messages-container');
  if (!container) return;

  if (placeholder || activeMessages.length === 0) {
    container.innerHTML = `<div style="text-align: center; color: #64748b; margin: auto; font-size: 14px;">${escapeHtml(placeholder || 'No messages in this thread.')}</div>`;
    return;
  }

  container.innerHTML = activeMessages.map(([, msg]) => {
    const isAdmin = msg.isAdmin === true;
    const bubble = isAdmin
      ? 'align-self: flex-end; background: #2563eb; color: #ffffff;'
      : 'align-self: flex-start; background: #ffffff; color: #1e293b; border: 1px solid #e2e8f0;';
    const stamp = isAdmin ? 'rgba(255,255,255,0.75)' : '#64748b';

    return `
      <div style="max-width: 75%; padding: 10px 14px; border-radius: 8px; font-size: 14px; word-break: break-word; ${bubble}">
        <div>${escapeHtml(msg.message || '')}</div>
        <div style="margin-top: 4px; font-size: 11px; color: ${stamp};">${escapeHtml(formatTime(msg.timestamp))}</div>
      </div>
    `;
  }).join('');

  container.scrollTop = container.scrollHeight;
}

// Marks the selected conversation as read, but only while the admin can
// actually see it.
function markActiveRead() {
  if (!activeUserId || !chatsTabIsOpen()) return;
  const thread = threads[activeUserId];
  if (!thread || !isUnread(thread)) return;

  update(ref(db, `chatThreads/${activeUserId}`), { adminReadAt: serverTimestamp() })
    .catch((err) => console.error('Could not mark the chat as read:', err));
}

window.sendAdminChatMessage = async function(event) {
  event.preventDefault();
  if (!activeUserId) {
    notify("Please select a conversation thread first.");
    return;
  }
  const adminUid = auth.currentUser?.uid;
  if (!adminUid) {
    notify("You are signed out. Please sign in again.");
    return;
  }

  const inputEl = document.getElementById('admin-chat-input');
  const text = inputEl.value.trim();
  if (!text) return;

  const userId = activeUserId;
  const key = push(ref(db, `chats/${userId}/messages`)).key;

  // The message and the thread summary are written together so they never
  // disagree.
  const updates = {
    [`chats/${userId}/messages/${key}`]: {
      message: text,
      senderId: adminUid,
      senderName: 'Store Admin',
      isAdmin: true,
      timestamp: serverTimestamp()
    },
    [`chatThreads/${userId}/lastMessage`]: text.slice(0, PREVIEW_LENGTH),
    [`chatThreads/${userId}/lastTimestamp`]: serverTimestamp(),
    [`chatThreads/${userId}/lastFromAdmin`]: true,
    [`chatThreads/${userId}/adminReadAt`]: serverTimestamp()
  };

  try {
    await update(ref(db), updates);
    inputEl.value = '';
  } catch (err) {
    console.error("Failed to send admin chat message:", err);
    notify("Failed to send message.");
  }
};
