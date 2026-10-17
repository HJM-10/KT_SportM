const handleError = require('../middleware/errorHandler');
const prisma = require('../lib/prisma');
const { randomUUID } = require('node:crypto');

const getMyMembership = async (req, res) => {
  try {
    const membership = await prisma.membership.findUnique({
      where: { userId: req.user.id }
    });
    res.json({ success: true, data: membership });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
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
    handleError(err, req, res);
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
      if (existing) {
        const payment = await tx.payment.findUnique({ where: { membershipId: existing.id } });
        if (payment?.status === 'PENDING' && existing.tier === tier) return { ...existing, paymentId: payment.id };
        if (payment || existing.isActive) throw Object.assign(new Error('Contact arena staff to change an existing membership; your current card and payment history are retained'), { status: 409 });
      }
      
      const membership = await tx.membership.upsert({
        where: { userId: req.user.id },
        update: { tier, isActive: amount === 0 }, // If basic (free), active immediately
        create: {
          userId: req.user.id,
          tier,
          cardNumber: `SSH-${randomUUID()}`,
          isActive: amount === 0
        }
      });

      if (amount > 0) {

        const payment = await tx.payment.create({
          data: {
            userId: req.user.id,
            amount,
            purpose: 'MEMBERSHIP',
            membershipId: membership.id,
            status: 'PENDING'
          }
        });
        membership.paymentId = payment.id;
      }

      return membership;
    });

    res.status(201).json({ success: true, data: result });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

module.exports = { getMyMembership, getAllMemberships, purchaseMembership };

