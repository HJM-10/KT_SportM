const prisma = require('../lib/prisma');
const { getStripe } = require('../lib/stripe');

async function settle(session) {
  if (session.payment_status !== 'paid') return;
  const id = Number(session.metadata?.paymentId);
  if (!Number.isSafeInteger(id)) throw new Error('Missing payment reference');
  await prisma.$transaction(async tx => {
    const payment = await tx.payment.findUnique({ where: { id } });
    if (!payment || session.amount_total !== Math.round(payment.amount * 100) || session.currency !== payment.currency.toLowerCase()) throw new Error('Payment amount or currency mismatch');
    if (payment.status === 'PAID') return;
    if (payment.status !== 'PENDING') throw new Error('Payment is no longer pending');
    if (payment.bookingId) {
      const booking = await tx.booking.findUnique({ where: { id: payment.bookingId } });
      if (!booking || booking.status !== 'PENDING_PAYMENT') throw new Error('Booking requires payment reconciliation');
      await tx.booking.update({ where: { id: booking.id }, data: { status: 'CONFIRMED' } });
    }
    const claimed = await tx.payment.updateMany({ where: { id, status: 'PENDING' }, data: { status: 'PAID', stripePaymentIntentId: session.payment_intent } });
    if (!claimed.count) return;
    if (payment.membershipId) await tx.membership.update({ where: { id: payment.membershipId }, data: { isActive: true } });
    await tx.notification.create({ data: { userId: payment.userId, title: 'Payment received', body: `Payment #${id} of ${payment.currency} ${payment.amount} was received.`, type: 'PAYMENT' } });
  });
}

async function checkout(req, res, next) {
  try {
    const id = Number(req.body.paymentId);
    if (!Number.isSafeInteger(id) || id < 1) return res.status(400).json({ success: false, message: 'Valid paymentId required' });
    const payment = await prisma.payment.findUnique({ where: { id } });
    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    if (payment.userId !== req.user.id) return res.status(403).json({ success: false, message: 'Not authorized' });
    if (payment.status !== 'PENDING') return res.status(409).json({ success: false, message: 'Payment is not pending' });
    if (payment.amount <= 0) return res.status(400).json({ success: false, message: 'No payment is due' });
    const origin = process.env.PUBLIC_API_URL || 'http://localhost:5000';
    const session = await getStripe().checkout.sessions.create({
      mode: 'payment',
      client_reference_id: String(id), metadata: { paymentId: String(id) },
      payment_intent_data: { metadata: { paymentId: String(id) } },
      line_items: [{ price_data: { currency: payment.currency.toLowerCase(), unit_amount: Math.round(payment.amount * 100), product_data: { name: `Smart Sports Hub ${payment.purpose.replaceAll('_', ' ')} #${id}` } }, quantity: 1 }],
      success_url: `${origin}/api/payments/return?status=success`,
      cancel_url: `${origin}/api/payments/return?status=cancelled`,
    }, { idempotencyKey: `checkout-${id}-${Math.floor(Date.now() / 1800000)}` });
    res.json({ success: true, data: { url: session.url } });
  } catch (error) { next(error); }
}

async function webhook(req, res) {
  let event;
  try {
    if (!process.env.STRIPE_WEBHOOK_SECRET) return res.sendStatus(503);
    event = getStripe().webhooks.constructEvent(req.body, req.headers['stripe-signature'], process.env.STRIPE_WEBHOOK_SECRET);
  } catch { return res.status(400).json({ success: false, message: 'Invalid webhook signature' }); }
  try {
    if (['checkout.session.completed', 'checkout.session.async_payment_succeeded'].includes(event.type)) await settle(event.data.object);
    res.json({ received: true });
  } catch (error) { console.error('Stripe settlement failed:', error.message); res.sendStatus(500); }
}
module.exports = { checkout, webhook, settle };

