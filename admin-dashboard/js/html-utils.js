// Customer names, addresses, reviews and chat text are typed by users.
// Always pass them through escapeHtml before putting them in innerHTML.
export function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Use for values placed inside an inline handler, e.g.
//   onclick="doThing(${jsArg(id)})"
// JSON.stringify makes a safe JavaScript string literal (quotes and
// backslashes escaped); escapeHtml then makes it safe inside the HTML
// attribute. escapeHtml alone is NOT enough inside onclick="...('x')".
export function jsArg(value) {
  return escapeHtml(JSON.stringify(String(value ?? '')));
}
