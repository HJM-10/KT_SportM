const prisma = require('../lib/prisma');
const { v4: uuidv4 } = require('uuid');

const getMyMembership = async (req, res) => {
  try {
    const membership = await prisma.membership.findUnique({
      where: { userId: req.user.id }
    });
    res.json({ success: true, data: membership });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getAllMemberships = async (req, res) => {
  try {
    const memberships = await prisma.membership.findMany({
      include: { user: { select: { id: true, name: true, email: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: memberships });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const purchaseMembership = async (req, res) => {
  try {
    const { tier } = req.body;
    if (!['BASIC', 'SILVER', 'GOLD'].includes(tier)) {
      return res.status(400).json({ success: false, message: 'Invalid membership tier' });
    }

    let amount = 0;
    if (tier === 'SILVER') amount = 1000;
    if (tier === 'GOLD') amount = 2500;

    const result = await prisma.$transaction(async (tx) => {
      const existing = await tx.membership.findUnique({ where: { userId: req.user.id } });
      
      const membership = await tx.membership.upsert({
        where: { userId: req.user.id },
        update: { tier, isActive: amount === 0 }, // If basic (free), active immediately
        create: {
          userId: req.user.id,
          tier,
          cardNumber: `SSH-${Math.floor(100000 + Math.random() * 900000)}`,
          isActive: amount === 0
        }
      });

      if (amount > 0) {
        const stripePaymentIntentId = `pi_dummy_${uuidv4()}`;
        const stripeClientSecret = `${stripePaymentIntentId}_secret_${uuidv4()}`;

        const payment = await tx.payment.create({
          data: {
            userId: req.user.id,
            amount,
            purpose: 'MEMBERSHIP',
            membershipId: membership.id,
            stripePaymentIntentId,
            stripeClientSecret,
            status: 'PENDING'
          }
        });
        membership.clientSecret = stripeClientSecret;
        membership.paymentId = payment.id;
      }

      return membership;
    });

    res.status(201).json({ success: true, data: result });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getMyMembership, getAllMemberships, purchaseMembership };
