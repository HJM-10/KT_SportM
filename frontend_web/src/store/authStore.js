import { create } from 'zustand';
import api from '../api/axios';

const useAuthStore = create((set) => ({
  user: null,
  token: sessionStorage.getItem('ssh_token') || null,
  isAuthenticated: false,
  isLoading: true, // true until server verifies the token

  // Called once on app startup — validates token against server
  init: async () => {
    const token = sessionStorage.getItem('ssh_token');
    if (!token) {
      set({ isLoading: false, isAuthenticated: false, user: null });
      return;
    }
    try {
      const res = await api.get('/auth/me');
      // Trust only server-returned user data, never sessionStorage role
      set({ user: res.data.data, isAuthenticated: true, isLoading: false });
    } catch {
      // Token is invalid or expired — clear everything
      sessionStorage.removeItem('ssh_token');
      set({ user: null, token: null, isAuthenticated: false, isLoading: false });
    }
  },

  login: async (email, password) => {
    const res = await api.post('/auth/login', { email, password });
    const { user, token } = res.data.data;
    sessionStorage.setItem('ssh_token', token);
    set({ user, token, isAuthenticated: true });
    return user;
  },

  register: async (name, email, password, phone) => {
    const res = await api.post('/auth/register', { name, email, password, phone });
    const { user, token } = res.data.data;
    sessionStorage.setItem('ssh_token', token);
    set({ user, token, isAuthenticated: true });
    return user;
  },

  updateUser: (updatedUser) => {
    set((state) => ({ user: { ...state.user, ...updatedUser } }));
  },

  logout: () => {
    sessionStorage.removeItem('ssh_token');
    set({ user: null, token: null, isAuthenticated: false });
  }
}));

export default useAuthStore;
