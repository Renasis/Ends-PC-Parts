// Who can open what in the dashboard.
//
//   admin  everything, including the Team tab (create / remove accounts)
//   staff  only the tabs listed here
//
// This only decides which screens are shown. The real limits are in
// database.rules.json: a staff account is refused by the database even if it
// opens a hidden screen. If you add a tab for staff here, give the `staff`
// role the matching access in the rules as well.
// The first entry is the screen staff land on after signing in.
export const STAFF_TABS = [
  'staff-home', 'orders', 'verification', 'returns', 'products',
  'inventory', 'customers', 'chats', 'reviews'
];

export const ROLE_LABELS = { admin: 'Admin', staff: 'Staff' };

export function canOpenTab(role, tabName) {
  return role === 'admin' || STAFF_TABS.includes(tabName);
}
