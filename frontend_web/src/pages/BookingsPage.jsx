import { useState, useEffect } from 'react';
import api from '../api/axios';
import toast from 'react-hot-toast';

const BookingsPage = () => {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchBookings = async () => {
    try {
      setLoading(true);
      const res = await api.get('/bookings');
      setBookings(res.data.data);
    } catch (err) {
      toast.error('Failed to load bookings');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchBookings(); }, []);

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">All Bookings</h1>
        <div className="page-subtitle">View all customer reservations</div>
      </div>

      {loading ? (
        <div className="loader-wrap"><div className="spinner"></div></div>
      ) : (
        <div className="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Customer</th>
                <th>Sport / Venue</th>
                <th>Date & Time</th>
                <th>Status</th>
                <th>Price</th>
              </tr>
            </thead>
            <tbody>
              {bookings.map(b => (
                <tr key={b.id}>
                  <td>#{b.id}</td>
                  <td>
                    <div style={{fontWeight: 600}}>{b.user?.name}</div>
                    <div className="text-muted" style={{fontSize: 12}}>{b.user?.email}</div>
                  </td>
                  <td>
                    <div style={{fontWeight: 600}}>{b.slot?.venue?.sport?.name}</div>
                    <div className="text-muted" style={{fontSize: 12}}>{b.slot?.venue?.name}</div>
                  </td>
                  <td>
                    <div>{new Date(b.slot?.date).toLocaleDateString()}</div>
                    <div className="text-muted" style={{fontSize: 12}}>{b.slot?.startTime} - {b.slot?.endTime}</div>
                  </td>
                  <td>
                    <span className={`badge badge-${b.status === 'CONFIRMED' ? 'primary' : b.status === 'SCANNED' ? 'success' : 'danger'}`}>
                      {b.status}
                    </span>
                  </td>
                  <td style={{fontWeight: 700}}>${b.totalPrice}</td>
                </tr>
              ))}
              {bookings.length === 0 && (
                <tr><td colSpan="6" className="text-center py-8">No bookings found</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default BookingsPage;
