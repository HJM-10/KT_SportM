const prisma = require('../lib/prisma');
const { createNotification } = require('../lib/notifications');
const { v4: uuidv4 } = require('uuid');

const initiatePayment = async (req, res) => {
  try {
    const { amount, purpose, bookingId, tournamentRegId, membershipId, eventRegId, rentalId } = req.body;
    
    if (!amount || !purpose) {
      return res.status(400).json({ success: false, message: 'Amount and purpose are required' });
    }

    // Create a dummy Stripe client secret (in a real app, this would come from Stripe API)
    const stripePaymentIntentId = `pi_dummy_${uuidv4()}`;
    const stripeClientSecret = `${stripePaymentIntentId}_secret_${uuidv4()}`;

    const payment = await prisma.payment.create({
      data: {
        userId: req.user.id,
        amount: parseFloat(amount),
        purpose,
        stripePaymentIntentId,
        stripeClientSecret,
        bookingId: bookingId ? parseInt(bookingId) : null,
        tournamentRegId: tournamentRegId ? parseInt(tournamentRegId) : null,
        membershipId: membershipId ? parseInt(membershipId) : null,
        eventRegId: eventRegId ? parseInt(eventRegId) : null,
        rentalId: rentalId ? parseInt(rentalId) : null,
        status: 'PENDING'
      }
    });

    res.json({ success: true, data: { payment, clientSecret: stripeClientSecret } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const confirmPayment = async (req, res) => {
  try {
    const { paymentId, paymentIntentId } = req.body;
    
    const payment = await prisma.payment.findUnique({
      where: { id: parseInt(paymentId) }
    });

    if (!payment) return res.status(404).json({ success: false, message: 'Payment not found' });
    if (payment.status === 'PAID') return res.status(400).json({ success: false, message: 'Payment already processed' });
    
    // In a real app, verify with Stripe that paymentIntentId succeeded.
    // Here we just mark it as PAID.
    const updatedPayment = await prisma.payment.update({
      where: { id: payment.id },
      data: { status: 'PAID' }
    });

    // Handle post-payment logic based on purpose
    if (payment.purpose === 'BOOKING' && payment.bookingId) {
      await prisma.booking.update({
        where: { id: payment.bookingId },
        data: { status: 'CONFIRMED' }
      });
      await createNotification(payment.userId, 'Booking Confirmed', `Your payment of Rs. ${payment.amount} was successful and your booking is confirmed.`, 'BOOKING');
    } else if (payment.purpose === 'MEMBERSHIP' && payment.membershipId) {
      await prisma.membership.update({
        where: { id: payment.membershipId },
        data: { isActive: true }
      });
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
    res.status(500).json({ success: false, message: 'Server error' });
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
    res.status(500).json({ success: false, message: 'Server error' });
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
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { initiatePayment, confirmPayment, getMyPayments, getAllPayments };
