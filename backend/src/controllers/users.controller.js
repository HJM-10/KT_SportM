const prisma = require('../lib/prisma');

const getUsers = async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        createdAt: true,
        _count: {
          select: {
            bookings: true,
            payments: true,
            complaints: true
          }
        },
        bookings: {
          select: {
            finalPrice: true,
            status: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    // Calculate total spent for each user
    const usersWithStats = users.map(user => {
      const totalSpent = user.bookings
        .filter(b => b.status === 'CONFIRMED' || b.status === 'SCANNED')
        .reduce((sum, b) => sum + b.finalPrice, 0);
      
      const { bookings, ...userData } = user; // remove raw bookings array
      return {
        ...userData,
        totalSpent
      };
    });

    res.json({ success: true, data: usersWithStats });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getUsers };
