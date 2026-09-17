import { useState, useEffect } from 'react';
import axios from '../api/axios';
import useAuthStore from '../store/authStore';
import toast from 'react-hot-toast';

const EquipmentPage = () => {
  const { user } = useAuthStore();
  const isAdmin = user?.role === 'ADMIN';
  const [equipment, setEquipment] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchEquipment = async () => {
    try {
      const res = await axios.get('/equipment');
      if (res.data.success) {
        setEquipment(res.data.data);
      }
    } catch (err) {
      toast.error('Failed to load equipment');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEquipment();
  }, []);

  const handleRent = async (equipmentId, price) => {
    const rentDate = new Date();
    rentDate.setHours(rentDate.getHours() + 1); // Rent for next hour
    try {
      const res = await axios.post(`/equipment/${equipmentId}/rent`, {
        quantity: 1,
        rentalDate: rentDate.toISOString()
      });
      if (res.data.success) {
        toast.success('Rental request created. Please complete payment.');
        fetchEquipment();
      }
    } catch (err) {
      toast.error(err.response?.data?.message || 'Rental failed');
    }
  };

  if (loading) return <div className="p-6 text-white text-center">Loading equipment...</div>;

  return (
    <div className="p-6 text-white h-full overflow-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-400">
          Equipment Rental
        </h1>
        {isAdmin && (
          <button className="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg transition-colors shadow-[0_0_15px_rgba(147,51,234,0.5)]">
            + Add Equipment
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        {equipment.map(item => (
          <div key={item.id} className="glass-panel p-4 flex flex-col hover:-translate-y-1 transition-all duration-300">
            <div className="h-40 bg-white/5 rounded-lg mb-4 flex items-center justify-center overflow-hidden border border-white/10">
              {item.imageUrl ? (
                <img src={item.imageUrl} alt={item.name} className="object-cover w-full h-full" />
              ) : (
                <span className="text-4xl">🏅</span>
              )}
            </div>
            <h3 className="text-lg font-bold text-white mb-1">{item.name}</h3>
            <p className="text-gray-400 text-sm mb-3 line-clamp-2">{item.description}</p>
            
            <div className="mt-auto pt-4 border-t border-white/10">
              <div className="flex justify-between items-end mb-4">
                <div>
                  <div className="text-xs text-gray-400 mb-1">Price per slot</div>
                  <div className="text-xl font-bold text-emerald-400">Rs. {item.pricePerSlot}</div>
                </div>
                <div className="text-right">
                  <div className="text-xs text-gray-400 mb-1">Available</div>
                  <div className="text-sm text-white font-medium">{item.quantity} units</div>
                </div>
              </div>

              {!isAdmin && (
                <button 
                  onClick={() => handleRent(item.id, item.pricePerSlot)}
                  className="w-full bg-white/10 hover:bg-purple-600 text-white py-2 rounded-lg transition-colors border border-white/20 hover:border-purple-500"
                  disabled={!item.isActive || item.quantity < 1}
                >
                  {!item.isActive || item.quantity < 1 ? 'Unavailable' : 'Rent Now'}
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default EquipmentPage;
