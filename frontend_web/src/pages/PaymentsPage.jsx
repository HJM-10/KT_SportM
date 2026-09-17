import { useState, useEffect } from 'react';
import axios from '../api/axios';
import toast from 'react-hot-toast';

const PaymentsPage = () => {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchPayments = async () => {
    try {
      const res = await axios.get('/payments');
      if (res.data.success) {
        setPayments(res.data.data);
      }
    } catch (err) {
      toast.error('Failed to load payments');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPayments();
  }, []);

  if (loading) return <div className="p-6 text-white text-center">Loading payments...</div>;

  return (
    <div className="p-6 text-white h-full overflow-auto">
      <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-green-400 to-emerald-400 mb-8">
        Payments
      </h1>

      <div className="glass-panel overflow-hidden">
        <table className="w-full text-left text-sm text-gray-300">
          <thead className="text-xs uppercase bg-white/5 text-gray-400 border-b border-white/10">
            <tr>
              <th className="px-6 py-4">ID</th>
              <th className="px-6 py-4">Date</th>
              <th className="px-6 py-4">User</th>
              <th className="px-6 py-4">Purpose</th>
              <th className="px-6 py-4">Amount</th>
              <th className="px-6 py-4">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5">
            {payments.map(payment => (
              <tr key={payment.id} className="hover:bg-white/5 transition-colors">
                <td className="px-6 py-4 text-gray-500">#{payment.id}</td>
                <td className="px-6 py-4">{new Date(payment.createdAt).toLocaleDateString()}</td>
                <td className="px-6 py-4">
                  <div className="font-bold text-white">{payment.user?.name}</div>
                  <div className="text-xs text-gray-500">{payment.user?.email}</div>
                </td>
                <td className="px-6 py-4 text-blue-400 font-medium">{payment.purpose.replace(/_/g, ' ')}</td>
                <td className="px-6 py-4 font-bold text-emerald-400">Rs. {payment.amount}</td>
                <td className="px-6 py-4">
                  <span className={`px-2 py-1 rounded text-xs font-bold ${
                    payment.status === 'PAID' ? 'bg-emerald-500/20 text-emerald-400' :
                    payment.status === 'PENDING' ? 'bg-yellow-500/20 text-yellow-400' :
                    'bg-red-500/20 text-red-400'
                  }`}>
                    {payment.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {payments.length === 0 && (
          <div className="p-8 text-center text-gray-400">No payments found.</div>
        )}
      </div>
    </div>
  );
};

export default PaymentsPage;
