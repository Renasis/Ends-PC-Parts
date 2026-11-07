// Pure helpers for the new-order alerts (no Firebase or DOM, so they are easy to test).

// Turns the raw `transactions` value (object or array) into [id, order] pairs.
export function toEntries(data) {
  if (!data) return [];
  const pairs = Array.isArray(data)
    ? data.map((order, index) => [String(index), order])
    : Object.entries(data);
  return pairs.filter(([, order]) => order && typeof order === 'object');
}

// Newest order first. Sorts by createdAt and, for equal or missing times, by id
// (push ids grow with time), so the list never depends on the order in which
// Firebase happens to hand the orders over.
// `a` and `b` are { id, createdAt }.
export function compareNewest(a, b) {
  const diff = (Number(b.createdAt) || 0) - (Number(a.createdAt) || 0);
  return diff !== 0 ? diff : String(b.id).localeCompare(String(a.id));
}

// Sorts [id, order] pairs, newest first.
export function newestFirst(entries) {
  return [...entries].sort(([idA, a], [idB, b]) =>
    compareNewest({ id: idA, createdAt: a?.createdAt }, { id: idB, createdAt: b?.createdAt }));
}

// Compares a snapshot with the ids already seen.
// `known` is null before the first snapshot: that one only fills the list,
// so the orders that were already there never trigger an alert.
// Returns { fresh, known } where fresh = new Pending orders, oldest first.
export function detectNewOrders(known, data) {
  const entries = toEntries(data);
  const ids = entries.map(([id]) => id);

  if (known === null) return { fresh: [], known: new Set(ids) };

  const fresh = entries
    .filter(([id, order]) => !known.has(id) && (order.status || 'Pending') === 'Pending')
    .sort((a, b) => (a[1].createdAt || 0) - (b[1].createdAt || 0));

  return { fresh, known: new Set([...known, ...ids]) };
}

// Finds orders the customer just cancelled themselves.
// `known` is a Map of id -> status, or null before the first snapshot (that
// one only fills the map). Returns { cancelled, statuses }.
export function detectCustomerCancellations(known, data) {
  const entries = toEntries(data);
  const statuses = new Map(entries.map(([id, order]) => [id, order.status || 'Pending']));

  if (known === null) return { cancelled: [], statuses };

  const cancelled = entries.filter(([id, order]) =>
    known.has(id) &&
    known.get(id) !== 'Cancelled' &&
    order.status === 'Cancelled' &&
    order.cancelledBy === 'customer');

  return { cancelled, statuses };
}

export function formatPeso(value) {
  let raw = value ?? 0;
  if (typeof raw === 'string') raw = raw.replace(/[^0-9.-]+/g, '');
  const amount = parseFloat(raw) || 0;
  return `₱${amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export function needsPaymentCheck(order) {
  const status = order.paymentStatus || order.paymentVerificationStatus || '';
  return (order.paymentMethod || '').toLowerCase() !== 'cod' && status === 'pending_verification';
}

// One line of plain text for a toast or a desktop notification.
export function describeOrder(id, order) {
  const parts = [
    `#${String(id).substring(0, 8)}`,
    order.recipientName || 'New customer',
    formatPeso(order.grandTotal),
    order.paymentMethod || 'COD'
  ];
  return parts.join(' · ');
}
