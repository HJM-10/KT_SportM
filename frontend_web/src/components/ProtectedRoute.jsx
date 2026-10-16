import { Navigate } from 'react-router-dom';
import useAuthStore from '../store/authStore';

const ProtectedRoute = ({ children, adminOnly = false }) => {
  const { isAuthenticated, isLoading, user } = useAuthStore();

  // Show nothing (or spinner) while token is being verified against server
  if (isLoading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh' }}>
        <div className="spinner" />
      </div>
    );
  }

  // Not authenticated — redirect to login
  if (!isAuthenticated) return <Navigate to="/login" replace />;

  // Admin-only route: role comes from server-verified user object, not localStorage
  if (adminOnly && user?.role !== 'ADMIN') return <Navigate to="/" replace />;

  return children;
};

export default ProtectedRoute;
