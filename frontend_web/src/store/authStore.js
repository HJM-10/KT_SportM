import { create } from 'zustand';
import api from '../api/axios';

const useAuthStore = create((set) => ({
  user: JSON.parse(localStorage.getItem('ssh_user') || 'null'),
  token: localStorage.getItem('ssh_token') || null,
  isAuthenticated: !!localStorage.getItem('ssh_token'),

  login: async (email, password) => {
    const res = await api.post('/auth/login', { email, password });
    const { user, token } = res.data.data;
    localStorage.setItem('ssh_token', token);
    localStorage.setItem('ssh_user', JSON.stringify(user));
    set({ user, token, isAuthenticated: true });
    return user;
  },

  register: async (name, email, password, phone) => {
    const res = await api.post('/auth/register', { name, email, password, phone });
    const { user, token } = res.data.data;
    localStorage.setItem('ssh_token', token);
    localStorage.setItem('ssh_user', JSON.stringify(user));
    set({ user, token, isAuthenticated: true });
    return user;
  },

  logout: () => {
    localStorage.removeItem('ssh_token');
    localStorage.removeItem('ssh_user');
    set({ user: null, token: null, isAuthenticated: false });
  }
}));

export default useAuthStore;
