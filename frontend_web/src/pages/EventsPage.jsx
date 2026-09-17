import { useState, useEffect } from 'react';
import axios from '../api/axios';
import useAuthStore from '../store/authStore';
import toast from 'react-hot-toast';

const EventsPage = () => {
  const { user } = useAuthStore();
  const isAdmin = user?.role === 'ADMIN';
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchEvents = async () => {
    try {
      const res = await axios.get('/events');
      if (res.data.success) {
        setEvents(res.data.data);
      }
    } catch (err) {
      toast.error('Failed to load events');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEvents();
  }, []);

  const handleRegister = async (eventId, fee) => {
    try {
      const res = await axios.post(`/events/${eventId}/register`);
      if (res.data.success) {
        if (fee > 0 && res.data.data.clientSecret) {
          toast.success('Registration successful. Please complete payment.');
          // In real app, redirect to payment page
        } else {
          toast.success('Successfully registered for event!');
        }
        fetchEvents();
      }
    } catch (err) {
      toast.error(err.response?.data?.message || 'Registration failed');
    }
  };

  if (loading) return <div className="p-6 text-white text-center">Loading events...</div>;

  return (
    <div className="p-6 text-white h-full overflow-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-emerald-400">
          Events & Training Camps
        </h1>
        {isAdmin && (
          <button className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors shadow-[0_0_15px_rgba(37,99,235,0.5)]">
            + Create Event
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {events.map(event => (
          <div key={event.id} className="glass-panel p-5 flex flex-col hover:border-blue-500/50 transition-all duration-300">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h3 className="text-xl font-bold text-white mb-1">{event.name}</h3>
                <span className="inline-block px-2 py-1 bg-white/10 rounded text-xs text-blue-300 border border-white/5">
                  {event.type}
                </span>
              </div>
              <div className="text-2xl">{event.sport?.icon}</div>
            </div>
            
            <p className="text-gray-400 text-sm mb-4 line-clamp-2">{event.description}</p>
            
            <div className="space-y-2 text-sm text-gray-300 mb-6">
              <div className="flex justify-between">
                <span>Start:</span>
                <span className="text-white">{new Date(event.startDate).toLocaleDateString()}</span>
              </div>
              <div className="flex justify-between">
                <span>Venue:</span>
                <span className="text-white">{event.venue}</span>
              </div>
              <div className="flex justify-between">
                <span>Fee:</span>
                <span className="text-emerald-400 font-bold">{event.fee > 0 ? `Rs. ${event.fee}` : 'Free'}</span>
              </div>
              <div className="flex justify-between">
                <span>Participants:</span>
                <span className="text-white">{event._count?.registrations || 0} {event.maxParticipants ? `/ ${event.maxParticipants}` : ''}</span>
              </div>
            </div>

            <div className="mt-auto">
              {!isAdmin && (
                <button 
                  onClick={() => handleRegister(event.id, event.fee)}
                  className="w-full bg-blue-600/80 hover:bg-blue-600 text-white py-2 rounded-lg transition-colors border border-blue-500/30"
                  disabled={event.status !== 'UPCOMING' || (event.maxParticipants && event._count?.registrations >= event.maxParticipants)}
                >
                  {event.status !== 'UPCOMING' ? 'Closed' : 'Register Now'}
                </button>
              )}
            </div>
          </div>
        ))}
        {events.length === 0 && (
          <div className="col-span-full text-center py-12 text-gray-400 bg-white/5 rounded-xl border border-white/10">
            No events available at the moment.
          </div>
        )}
      </div>
    </div>
  );
};

export default EventsPage;
