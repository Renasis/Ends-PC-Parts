// Non-blocking notifications that replace window.alert().
// notify(message) guesses the style from the wording; pass a type
// ('success' | 'error' | 'warning' | 'info') to force one.

const ERROR_HINTS = /^(failed|could not|couldn't|unable|error)/i;
const WARN_HINTS = /^(please|enter|invalid|not enough|no |this payment was already|description must|product name must|rejection reason)/i;

function guessType(message) {
  const text = String(message).trim();
  if (ERROR_HINTS.test(text)) return 'error';
  if (WARN_HINTS.test(text)) return 'warning';
  return 'success';
}

function getContainer() {
  let box = document.getElementById('toast-container');
  if (!box) {
    box = document.createElement('div');
    box.id = 'toast-container';
    box.className = 'toast-container';
    box.setAttribute('role', 'status');
    box.setAttribute('aria-live', 'polite');
    document.body.appendChild(box);
  }
  return box;
}

export function notify(message, type) {
  const kind = type || guessType(message);
  const toast = document.createElement('div');
  toast.className = `toast toast-${kind}`;

  const text = document.createElement('span');
  text.textContent = String(message);

  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'toast-close';
  close.setAttribute('aria-label', 'Dismiss notification');
  close.textContent = '\u00d7';

  const remove = () => {
    toast.classList.add('toast-leaving');
    setTimeout(() => toast.remove(), 200);
  };
  close.addEventListener('click', remove);

  toast.append(text, close);
  getContainer().appendChild(toast);
  setTimeout(remove, kind === 'error' ? 7000 : 4500);
}

// A toast with a title, a message and one action button (e.g. "View order").
// Stays longer than a normal toast because the admin may not be looking.
export function showActionToast({ title, message, actionLabel, onAction, kind = 'order', duration = 20000 }) {
  const toast = document.createElement('div');
  toast.className = `toast toast-${kind}`;

  const body = document.createElement('div');
  body.className = 'toast-body';

  const heading = document.createElement('strong');
  heading.className = 'toast-title';
  heading.textContent = String(title);

  const text = document.createElement('span');
  text.className = 'toast-text';
  text.textContent = String(message);

  body.append(heading, text);

  const remove = () => {
    toast.classList.add('toast-leaving');
    setTimeout(() => toast.remove(), 200);
  };

  if (actionLabel && typeof onAction === 'function') {
    const action = document.createElement('button');
    action.type = 'button';
    action.className = 'toast-action';
    action.textContent = actionLabel;
    action.addEventListener('click', () => { remove(); onAction(); });
    body.appendChild(action);
  }

  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'toast-close';
  close.setAttribute('aria-label', 'Dismiss notification');
  close.textContent = '\u00d7';
  close.addEventListener('click', remove);

  toast.append(body, close);
  getContainer().appendChild(toast);
  setTimeout(remove, duration);
}

window.notify = notify;
