// "Show / Hide" button next to a password box:
//   <div class="password-field">
//     <input type="password" id="x">
//     <button type="button" class="password-toggle" data-target="x">Show</button>
//   </div>
document.addEventListener('click', (event) => {
  const button = event.target.closest('.password-toggle');
  if (!button) return;

  const input = document.getElementById(button.dataset.target);
  if (!input) return;

  const show = input.type === 'password';
  input.type = show ? 'text' : 'password';
  button.textContent = show ? 'Hide' : 'Show';
  button.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
  button.setAttribute('aria-pressed', String(show));
  input.focus();
});
