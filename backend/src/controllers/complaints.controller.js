const prisma = require('../lib/prisma');
const { createNotification } = require('../lib/notifications');
const socket = require('../lib/socket');

const submitComplaint = async (req, res) => {
  try {
    const { title, description, category } = req.body;
    if (!title || !description) {
      return res.status(400).json({ success: false, message: 'Title and description are required' });
    }

    const complaint = await prisma.complaint.create({
      data: {
        userId: req.user.id,
        title,
        description,
        category: category || 'General',
        status: 'OPEN'
      }
    });
    
    // Notify admin
    await createNotification(1, 'New Complaint', `A new complaint has been filed: ${title}`, 'COMPLAINT');

    res.status(201).json({ success: true, data: complaint });
    try { socket.getIO().emit('complaint_updated', {}); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getMyComplaints = async (req, res) => {
  try {
    const complaints = await prisma.complaint.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: complaints });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getAllComplaints = async (req, res) => {
  try {
    const complaints = await prisma.complaint.findMany({
      include: { user: { select: { id: true, name: true, email: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: complaints });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const updateComplaintStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminNote } = req.body;

    const complaint = await prisma.complaint.findUnique({ where: { id: parseInt(id) } });
    if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });

    const updated = await prisma.complaint.update({
      where: { id: parseInt(id) },
      data: { status, adminNote }
    });

    if (status !== complaint.status) {
      await createNotification(
        complaint.userId, 
        'Complaint Update', 
        `Your complaint "${complaint.title}" status has been updated to ${status}.`,
        'COMPLAINT'
      );
    }

    res.json({ success: true, data: updated });
    try { socket.getIO().emit('complaint_updated', {}); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { submitComplaint, getMyComplaints, getAllComplaints, updateComplaintStatus };


