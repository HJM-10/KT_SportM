const prisma = require('./prisma');

/**
 * Creates an in-app notification for a user.
 * @param {number} userId
 * @param {string} title
 * @param {string} body
 * @param {string} type  e.g. 'BOOKING', 'PAYMENT', 'COMPLAINT', 'GENERAL'
 * @param {object} data  optional JSON payload
 */
const createNotification = async (userId, title, body, type = 'INFO', data = null) => {
  try {
    await prisma.notification.create({
      data: { userId, title, body, type, data }
    });
  } catch (err) {
    console.error('[Notification] Failed to create notification:', err.message);
  }
};

module.exports = { createNotification };
