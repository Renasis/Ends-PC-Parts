# PC Parts Store — Flutter Customer App + Admin Dashboard

A Flutter e-commerce application for a PC parts store with a Firebase Realtime Database backend and a web-based admin dashboard.

## Project Structure

```
it7_lab_act/              # Flutter customer app (lib/, test/, pubspec.yaml)
admin-dashboard/          # Web admin dashboard (js/, css/, index.html)
```

## Customer App (Flutter)

### Features
- **Product browsing** with variant support (size, color, etc.) and image gallery
- **Shopping cart** with guest + synced cart (Firebase-backed for signed-in users)
- **Checkout** with COD and online payment (screenshot/reference proof)
- **Order tracking** with status (Pending → Processing → Shipping → Completed)
- **Returns & refunds** — customers can request returns with reason + photo; admins approve and process refunds
- **Order reorder** — reorder past completed orders from order history
- **Wishlist** — save favorite products
- **Shipping tracking** — carrier + tracking number displayed on orders

### Running
```bash
cd it7_lab_act
flutter pub get
flutter run
```

### Firebase
Configure `lib/firebase_options.dart` with your Firebase project settings. The app uses:
- Firebase Authentication (email/password)
- Firebase Realtime Database (products, transactions, users, carts)

### Running Tests
```bash
flutter test
```

## Admin Dashboard (Web)

### Features
- **Dashboard analytics** — order counts, revenue, status breakdown, top products, daily revenue
- **Product catalog** — add/edit/delete products with variants and multiple images
- **Order management** — view all orders, update status (Pending/Processing/Shipping/Completed/Cancelled/Returned), bulk status changes
- **Returns management** — review return requests, process refunds, view return reason + proof photo
- **Shipping** — set carrier + tracking number, notify customers
- **Inventory** — view stock levels, low-stock alerts
- **Customers** — view customer list and order history
- **Payments** — verify/reject online payment proofs
- **Promo codes** — create/edit/delete discount codes
- **Reports** — sales reports and analytics
- **Activity logs** — admin action audit trail
- **Settings** — shipping fee, payment methods

### Running
Open `admin-dashboard/index.html` in a browser or serve with any static file server:
```bash
cd admin-dashboard
# Using Python:
python -m http.server 8000
# Then open http://localhost:8000
```

### Firebase
The admin dashboard uses the same Firebase project as the Flutter app. Configure `admin-dashboard/js/firebase-config.js` with your Firebase project settings.

## Firebase Realtime Database Schema

### `/products/{id}`
```json
{
  "productName": "RTX 4090",
  "productPrice": 1599.99,
  "productStock": 5,
  "productDescription": "...",
  "category": "Graphics Cards",
  "imageUrl": "data:image/jpeg;base64,...",
  "imageUrls": ["data:image/jpeg;base64:..."],
  "variantOptions": [
    {"label": "Size: Large", "priceAdjustment": 50.0, "stock": 10, "sku": "RTX4090-L"}
  ]
}
```

### `/transactions/{id}`
```json
{
  "userId": "uid123",
  "status": "Completed",
  "paymentMethod": "Online Banking",
  "paymentStatus": "verified",
  "recipientName": "John Doe",
  "phoneNumber": "09123456789",
  "deliveryAddress": "123 Main St",
  "items": [...],
  "subtotal": 1599.99,
  "discount": 0,
  "shippingFee": 150,
  "grandTotal": 1749.99,
  "createdAt": 1704067200000,
  "cancellationReason": "",
  "returnReason": "",
  "returnedAt": 0,
  "refundAmount": 0,
  "refundStatus": "",
  "returnImageUrl": "",
  "shippingCarrier": "LBC",
  "trackingNumber": "PH123456789",
  "shippedAt": 1704153600000,
  "estimatedDelivery": 1704240000000,
  "adminNotes": ""
}
```

### `/users/{uid}`
```json
{
  "name": "John Doe",
  "phoneNumber": "09123456789",
  "deliveryAddress": "123 Main St",
  "cart": {"productId1": 2, "productId2|variant": 1}
}
```

## Spark Plan Compatibility

The entire app is designed to work on Firebase's **Spark (free) plan**:
- No Cloud Functions required
- No Cloud Storage required (images stored as base64 in Realtime Database)
- No external email service (in-app notifications only)
- RTDB queries use `.limitToFirst(100)` to control bandwidth

### Spark Plan Limitations
- **Email notifications** — not available without Blaze (Cloud Functions) or external SMTP
- **Abandoned cart recovery** — not available without scheduled backend triggers
- **Large catalogs** — RTDB queries limited to 100 records per collection

## Testing

```bash
# Flutter unit tests
flutter test

# Admin dashboard — open in browser and manually verify
```

## License

MIT