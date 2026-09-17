import { useState, useEffect } from 'react';
import axios from '../api/axios';
import toast from 'react-hot-toast';
import { BarChart3, TrendingUp, Users, Calendar, DollarSign } from 'lucide-react';

const ReportsPage = () => {
  const [revenue, setRevenue] = useState(null);
  const [bookings, setBookings] = useState(null);
  const [utilization, setUtilization] = useState(null);
  const [customers, setCustomers] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchReports = async () => {
    try {
      const [revRes, bookRes, utilRes, custRes] = await Promise.all([
        axios.get('/reports/revenue'),
        axios.get('/reports/bookings'),
        axios.get('/reports/utilization'),
        axios.get('/reports/customers')
      ]);
      
      setRevenue(revRes.data.data);
      setBookings(bookRes.data.data);
      setUtilization(utilRes.data.data);
      setCustomers(custRes.data.data);
    } catch (err) {
      toast.error('Failed to load reports');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchReports();
  }, []);

  const handleExport = () => {
    window.open('http://localhost:5000/api/reports/export/bookings', '_blank');
  };

  if (loading) return <div className="p-6 text-white text-center">Gathering analytics...</div>;

  return (
    <div className="p-6 text-white h-full overflow-auto">
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-indigo-400">
            Analytics & Reports
          </h1>
          <p className="text-gray-400 mt-1">Platform performance and insights</p>
        </div>
        <button 
          onClick={handleExport}
          className="bg-white/10 hover:bg-white/20 text-white px-4 py-2 rounded-lg transition-colors border border-white/10 flex items-center gap-2"
        >
          <BarChart3 size={18} /> Export Data
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="glass-panel p-6 border-b-4 border-b-emerald-500">
          <div className="flex justify-between items-start mb-4">
            <div className="text-gray-400">Total Revenue</div>
            <div className="p-2 bg-emerald-500/20 rounded-lg text-emerald-400"><DollarSign size={20} /></div>
          </div>
          <div className="text-3xl font-bold text-white">Rs. {revenue?.totalRevenue?.toLocaleString() || 0}</div>
        </div>
        
        <div className="glass-panel p-6 border-b-4 border-b-blue-500">
          <div className="flex justify-between items-start mb-4">
            <div className="text-gray-400">Facility Utilization</div>
            <div className="p-2 bg-blue-500/20 rounded-lg text-blue-400"><TrendingUp size={20} /></div>
          </div>
          <div className="text-3xl font-bold text-white">{utilization?.utilizationRate?.toFixed(1) || 0}%</div>
          <div className="text-sm text-gray-500 mt-2">{utilization?.bookedSlots} / {utilization?.totalSlots} slots booked</div>
        </div>

        <div className="glass-panel p-6 border-b-4 border-b-purple-500">
          <div className="flex justify-between items-start mb-4">
            <div className="text-gray-400">Total Customers</div>
            <div className="p-2 bg-purple-500/20 rounded-lg text-purple-400"><Users size={20} /></div>
          </div>
          <div className="text-3xl font-bold text-white">{customers?.totalCustomers || 0}</div>
        </div>

        <div className="glass-panel p-6 border-b-4 border-b-orange-500">
          <div className="flex justify-between items-start mb-4">
            <div className="text-gray-400">Completed Bookings</div>
            <div className="p-2 bg-orange-500/20 rounded-lg text-orange-400"><Calendar size={20} /></div>
          </div>
          <div className="text-3xl font-bold text-white">
            {(bookings?.statusCounts?.CONFIRMED || 0) + (bookings?.statusCounts?.SCANNED || 0)}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="glass-panel p-6">
          <h2 className="text-xl font-bold mb-6 text-white border-b border-white/10 pb-4">Top Spending Customers</h2>
          <div className="space-y-4">
            {customers?.topCustomers?.map((c, i) => (
              <div key={i} className="flex justify-between items-center bg-white/5 p-4 rounded-lg border border-white/5">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold">
                    {i + 1}
                  </div>
                  <div>
                    <div className="font-bold text-white">{c.user.name}</div>
                    <div className="text-xs text-gray-400">{c.user.email}</div>
                  </div>
                </div>
                <div className="text-emerald-400 font-bold">Rs. {c.totalSpent.toLocaleString()}</div>
              </div>
            ))}
            {(!customers?.topCustomers || customers.topCustomers.length === 0) && (
              <div className="text-center text-gray-400 py-4">No customer data yet.</div>
            )}
          </div>
        </div>
        
        <div className="glass-panel p-6">
          <h2 className="text-xl font-bold mb-6 text-white border-b border-white/10 pb-4">Revenue by Month</h2>
          <div className="space-y-4">
            {revenue?.revenueByMonth && Object.keys(revenue.revenueByMonth).length > 0 ? (
              Object.keys(revenue.revenueByMonth).sort().reverse().map(month => (
                <div key={month} className="flex flex-col gap-2 bg-white/5 p-4 rounded-lg border border-white/5">
                  <div className="flex justify-between items-center mb-1">
                    <div className="font-bold text-white">{month}</div>
                    <div className="text-emerald-400 font-bold">Rs. {revenue.revenueByMonth[month].toLocaleString()}</div>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-2">
                    <div 
                      className="bg-emerald-500 h-2 rounded-full" 
                      style={{ width: `${Math.min(100, (revenue.revenueByMonth[month] / revenue.totalRevenue) * 100)}%` }}
                    ></div>
                  </div>
                </div>
              ))
            ) : (
              <div className="text-center text-gray-400 py-4">No revenue data yet.</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default ReportsPage;
