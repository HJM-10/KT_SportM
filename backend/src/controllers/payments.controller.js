const handleError = require('../middleware/errorHandler');
const prisma = require('../lib/prisma');
const { createNotification } = require('../lib/notifications');


const initiatePayment = async (req, res) => {
  return res.status(409).json({ success: false, message: 'Create a booking, registration, rental or membership to obtain a server-priced payment record' });
};

const confirmPayment = async (req, res) => {
  try {
    if (req.user.role !== 'ADMIN') return res.status(403).json({ success: false, message: 'Admin access required' });
    const { paymentId } = req.body;
    if (!Number.isSafeInteger(Number(paymentId)) || Number(paymentId) < 1) return res.status(400).json({ success: false, message: 'Valid paymentId required' });
    
    const payment = await prisma.payment.findUnique({
      where: { id: parseInt(paymentId) }
    });

    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    if (payment.status !== 'PENDING') return res.status(409).json({ success: false, message: 'Payment is not pending' });
    if (payment.bookingId) {
      const booking = await prisma.booking.findUnique({ where: { id: payment.bookingId } });
      if (!booking || booking.status !== 'PENDING_PAYMENT') return res.status(409).json({ success: false, message: 'Booking is no longer awaiting payment' });
    }
    if (payment.status === 'PAID') return res.status(400).json({ success: false, message: 'Payment already processed' });
    
    if (req.body.receivedInPerson !== true) return res.status(400).json({ success: false, message: 'Explicit confirmation of money received in person is required' });
    if (payment.stripePaymentIntentId && !payment.stripePaymentIntentId.startsWith('pi_dummy_')) return res.status(409).json({ success: false, message: 'Online payments must be reconciled with the provider' });
    const updatedPayment = await prisma.$transaction(async tx => {
      const claimed = await tx.payment.updateMany({ where: { id: payment.id, status: 'PENDING' }, data: { status: 'PAID', stripePaymentIntentId: null, stripeClientSecret: null } });
      if (!claimed.count) throw Object.assign(new Error('Payment changed; refresh and retry'), { status: 409 });
      if (payment.bookingId) {
        const changed = await tx.booking.updateMany({ where: { id: payment.bookingId, status: 'PENDING_PAYMENT' }, data: { status: 'CONFIRMED' } });
        if (!changed.count) throw Object.assign(new Error('Booking changed; refresh and retry'), { status: 409 });
      }
      if (payment.membershipId) await tx.membership.update({ where: { id: payment.membershipId }, data: { isActive: true } });
      return tx.payment.findUnique({ where: { id: payment.id } });
    });

    // Handle post-payment logic based on purpose
    if (payment.purpose === 'BOOKING' && payment.bookingId) {
      await createNotification(payment.userId, 'Booking Confirmed', `Your payment of Rs. ${payment.amount} was successful and your booking is confirmed.`, 'BOOKING');
    } else if (payment.purpose === 'MEMBERSHIP' && payment.membershipId) {
      await createNotification(payment.userId, 'Membership Activated', `Your membership has been activated.`, 'PAYMENT');
    } else if (payment.purpose === 'TOURNAMENT_REGISTRATION' && payment.tournamentRegId) {
       // Registration is already created, payment is just marked PAID.
       await createNotification(payment.userId, 'Tournament Registration', `Your tournament registration fee was paid successfully.`, 'TOURNAMENT');
    } else if (payment.purpose === 'EVENT_REGISTRATION' && payment.eventRegId) {
      await createNotification(payment.userId, 'Event Registration', `Your event registration was successful.`, 'EVENT');
    } else if (payment.purpose === 'EQUIPMENT_RENTAL' && payment.rentalId) {
      await prisma.equipmentRental.update({
        where: { id: payment.rentalId },
        data: { status: 'CONFIRMED' }
      });
      await createNotification(payment.userId, 'Equipment Rental', `Your equipment rental payment was successful.`, 'RENTAL');
    }

    res.json({ success: true, data: updatedPayment });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

const getMyPayments = async (req, res) => {
  try {
    const payments = await prisma.payment.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: payments });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

const getAllPayments = async (req, res) => {
  try {
    const payments = await prisma.payment.findMany({
      include: { user: { select: { id: true, name: true, email: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: payments });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

module.exports = { initiatePayment, confirmPayment, getMyPayments, getAllPayments };


