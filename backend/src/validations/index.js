const { z } = require('zod');

const authSchemas = {
  register: z.object({
    body: z.object({
      name: z.string().min(2, 'Name must be at least 2 characters'),
      email: z.string().email('Invalid email address'),
      password: z.string().min(6, 'Password must be at least 6 characters'),
      phone: z.string().optional(),
      role: z.enum(['ADMIN', 'CUSTOMER']).optional()
    })
  }),
  login: z.object({
    body: z.object({
      email: z.string().email('Invalid email address'),
      password: z.string().min(1, 'Password is required'),
    })
  }),
  updateProfile: z.object({
    body: z.object({
      name: z.string().min(2, 'Name must be at least 2 characters').optional(),
      phone: z.string().optional()
    })
  }),
  changePassword: z.object({
    body: z.object({
      oldPassword: z.string().min(1, 'Current password is required'),
      newPassword: z.string().min(6, 'New password must be at least 6 characters')
    })
  })
};

const bookingSchemas = {
  createSlot: z.object({
    body: z.object({
      venueId: z.number().or(z.string().transform(Number)),
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
      startTime: z.string().regex(/^\d{2}:\d{2}$/, 'Start time must be HH:MM'),
      endTime: z.string().regex(/^\d{2}:\d{2}$/, 'End time must be HH:MM'),
    })
  }),
  createBooking: z.object({
    body: z.object({
      slotId: z.number().or(z.string().transform(Number)),
      notes: z.string().optional()
    })
  })
};

module.exports = { authSchemas, bookingSchemas };
