import { ref, push, update, get } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-database.js";
import { db } from "./firebase-config.js";

// Writes in-app notifications to notifications/{uid}/{pushId}.
// Fields the app reads: title, message, type ("order" | "price"), orderId,
// productId, timestamp (ms) and read.
// A failed notification must never block the order or product change that
// caused it, so these functions log the error and return instead of throwing.

function formatPeso(value) {
  const amount = parseFloat(value) || 0;
  return `₱${amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function entry(fields) {
  return { read: false, timestamp: Date.now(), ...fields };
}

async function writeNotifications(recipients, fields) {
  const updates = {};
  recipients.forEach((uid) => {
    const key = push(ref(db, `notifications/${uid}`)).key;
    updates[`notifications/${uid}/${key}`] = entry(fields);
  });
  if (Object.keys(updates).length === 0) return 0;
  await update(ref(db), updates);
  return recipients.length;
}

const ORDER_MESSAGES = {
  processing: ['Order confirmed', 'is confirmed and being prepared.'],
  shipping: ['Order shipped', 'is on its way to you.'],
  completed: ['Order completed', 'has been completed. Thank you for shopping with us!'],
  cancelled: ['Order cancelled', 'was cancelled.'],
  returned: ['Order returned', 'has been returned. Our team will process your refund.']
};

// Tells the customer that their order moved to [status].
export async function notifyOrderStatus(orderId, order, status, reason) {
  const uid = order?.userId;
  const copy = ORDER_MESSAGES[String(status).toLowerCase()];
  if (!uid || !copy) return;

  const [title, text] = copy;
  let message = `Order #${String(orderId).substring(0, 8)} ${text}`;
  if (String(status).toLowerCase() === 'cancelled' && reason) message += ` Reason: ${reason}`;

  try {
    await writeNotifications([uid], { title, message, type: 'order', orderId });
  } catch (err) {
    console.error('Could not notify the customer about the order:', err);
  }
}

// Tells the customer their payment was approved or rejected.
export async function notifyPaymentResult(orderId, order, approved, reason) {
  const uid = order?.userId;
  if (!uid) return;

  const shortId = String(orderId).substring(0, 8);
  const title = approved ? 'Payment verified' : 'Payment rejected';
  const message = approved
    ? `Your payment for order #${shortId} was verified. We are preparing your order.`
    : `Your payment for order #${shortId} was rejected. Reason: ${reason}`;

  try {
    await writeNotifications([uid], { title, message, type: 'order', orderId });
  } catch (err) {
    console.error('Could not notify the customer about the payment:', err);
  }
}

// Tells the customer their return was approved and a refund is on its way.
export async function notifyReturnApproved(orderId, order, refundAmount, note) {
  const uid = order?.userId;
  if (!uid) return;

  const shortId = String(orderId).substring(0, 8);
  const where = order.refundMethod ? ` to your ${order.refundMethod} account` : '';
  let message = `Your return for order #${shortId} was approved. We will send ${formatPeso(refundAmount)}${where} shortly.`;
  if (note) message += ` Note: ${note}`;

  try {
    await writeNotifications([uid], { title: 'Return approved', message, type: 'order', orderId });
  } catch (err) {
    console.error('Could not notify the customer about the approved return:', err);
  }
}

// Tells the customer their return request was declined, with the reason.
export async function notifyReturnRejected(orderId, order, reason) {
  const uid = order?.userId;
  if (!uid) return;

  const shortId = String(orderId).substring(0, 8);
  const message = `Your return request for order #${shortId} was declined. Reason: ${reason}`;

  try {
    await writeNotifications([uid], { title: 'Return declined', message, type: 'order', orderId });
  } catch (err) {
    console.error('Could not notify the customer about the declined return:', err);
  }
}

// Tells the customer their refund has been sent for a returned order.
export async function notifyRefundProcessed(orderId, order, refundAmount, reference = '') {
  const uid = order?.userId;
  if (!uid) return;

  const shortId = String(orderId).substring(0, 8);
  const amount = formatPeso(refundAmount);
  const title = 'Refund sent';
  const where = order.refundMethod ? ` to your ${order.refundMethod} account` : '';
  const refPart = reference ? ` Reference no.: ${reference}.` : '';
  const message = `Your refund of ${amount} for order #${shortId} has been sent${where}.${refPart}`;

  try {
    await writeNotifications([uid], { title, message, type: 'order', orderId });
  } catch (err) {
    console.error('Could not notify the customer about the refund:', err);
  }
}

// Tells the customer their order has shipped with tracking info.
export async function notifyOrderShipped(orderId, order, trackingNumber, shippingCarrier) {
  const uid = order?.userId;
  if (!uid) return;

  const shortId = String(orderId).substring(0, 8);
  const title = 'Order shipped';
  const trackingPart = trackingNumber ? ` Tracking: ${trackingNumber}` : '';
  const carrierPart = shippingCarrier ? ` via ${shippingCarrier}` : '';
  const message = `Your order #${shortId} has been shipped${carrierPart}${trackingPart}.`;

  try {
    await writeNotifications([uid], { title, message, type: 'order', orderId });
  } catch (err) {
    console.error('Could not notify the customer about shipping:', err);
  }
}

// Tells every customer who has the product in their wishlist that its price
// changed. Returns how many customers were notified.
export async function notifyPriceChange(productId, productName, oldPrice, newPrice) {
  try {
    const snapshot = await get(ref(db, 'users'));
    const users = snapshot.val() || {};
    const recipients = Object.keys(users).filter((uid) => users[uid]?.wishlist?.[productId]);

    const direction = parseFloat(newPrice) < parseFloat(oldPrice) ? 'dropped' : 'went up';
    return await writeNotifications(recipients, {
      title: `Price ${direction}`,
      message: `${productName} is now ${formatPeso(newPrice)} (was ${formatPeso(oldPrice)}).`,
      type: 'price',
      productId
    });
  } catch (err) {
    console.error('Could not notify wishlist customers about the price change:', err);
    return 0;
  }
}
