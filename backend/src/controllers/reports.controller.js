const prisma = require('../lib/prisma');

const getRevenueSummary = async (req, res) => {
  try {
    const bookings = await prisma.booking.findMany({
      where: { status: { in: ['CONFIRMED', 'SCANNED'] } },
      select: { finalPrice: true, createdAt: true, slot: { include: { venue: { select: { sportId: true } } } } }
    });

    const totalRevenue = bookings.reduce((sum, b) => sum + b.finalPrice, 0);

    // Group by month
    const revenueByMonth = {};
    bookings.forEach(b => {
      const month = b.createdAt.toISOString().substring(0, 7); // YYYY-MM
      revenueByMonth[month] = (revenueByMonth[month] || 0) + b.finalPrice;
    });

    res.json({ success: true, data: { totalRevenue, revenueByMonth } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getBookingAnalytics = async (req, res) => {
  try {
    const bookings = await prisma.booking.groupBy({
      by: ['status'],
      _count: { id: true }
    });

    const statusCounts = {};
    bookings.forEach(b => {
      statusCounts[b.status] = b._count.id;
    });

    res.json({ success: true, data: { statusCounts } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getUtilizationReport = async (req, res) => {
  try {
    const totalSlots = await prisma.bookingSlot.count();
    const bookedSlots = await prisma.bookingSlot.count({ where: { isBooked: true } });
    
    const utilizationRate = totalSlots > 0 ? (bookedSlots / totalSlots) * 100 : 0;
    
    res.json({ success: true, data: { totalSlots, bookedSlots, utilizationRate } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getCustomerAnalytics = async (req, res) => {
  try {
    const totalCustomers = await prisma.user.count({ where: { role: 'CUSTOMER' } });
    
    // Top customers by spending
    const topCustomersRaw = await prisma.booking.groupBy({
      by: ['userId'],
      _sum: { finalPrice: true },
      orderBy: { _sum: { finalPrice: 'desc' } },
      take: 5
    });
    
    const userIds = topCustomersRaw.map(t => t.userId);
    const users = await prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, name: true, email: true } });
    
    const topCustomers = topCustomersRaw.map(t => ({
      user: users.find(u => u.id === t.userId),
      totalSpent: t._sum.finalPrice || 0
    }));

    res.json({ success: true, data: { totalCustomers, topCustomers } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const exportBookingsCsv = async (req, res) => {
  try {
    const bookings = await prisma.booking.findMany({
      include: {
        user: { select: { name: true, email: true } },
        slot: { include: { venue: { select: { name: true } } } }
      },
      orderBy: { createdAt: 'desc' }
    });

    let csv = 'ID,Date,User Name,User Email,Venue,Total Price,Status\n';
    bookings.forEach(b => {
      const date = b.createdAt.toISOString().split('T')[0];
      const venue = b.slot?.venue?.name || '';
      csv += `${b.id},${date},"${b.user.name}","${b.user.email}","${venue}",${b.finalPrice},${b.status}\n`;
    });

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="bookings.csv"');
    res.send(csv);
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getRevenueSummary, getBookingAnalytics, getUtilizationReport, getCustomerAnalytics, exportBookingsCsv };

