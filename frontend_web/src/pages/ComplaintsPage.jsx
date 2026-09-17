import { useState, useEffect } from 'react';
import axios from '../api/axios';
import toast from 'react-hot-toast';

const ComplaintsPage = () => {
  const [complaints, setComplaints] = useState([]);
  const [loading, setLoading] = useState(true);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');

  const fetchComplaints = async () => {
    try {
      const res = await axios.get('/complaints/my');
      if (res.data.success) {
        setComplaints(res.data.data);
      }
    } catch (err) {
      toast.error('Failed to load complaints');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchComplaints();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const res = await axios.post('/complaints', { title, description });
      if (res.data.success) {
        toast.success('Complaint submitted successfully');
        setTitle('');
        setDescription('');
        fetchComplaints();
      }
    } catch (err) {
      toast.error('Failed to submit complaint');
    }
  };

  if (loading) return <div className="p-6 text-white">Loading...</div>;

  return (
    <div className="p-6 text-white h-full overflow-auto max-w-4xl mx-auto">
      <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-red-400 to-orange-400 mb-8">
        Help & Support
      </h1>

      <div className="glass-panel p-6 mb-8 border-red-500/30">
        <h2 className="text-xl font-semibold mb-4 text-white">File a Complaint</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-gray-400 mb-1">Subject</label>
            <input 
              type="text" 
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded px-4 py-2 text-white focus:outline-none focus:border-red-500"
              required
              placeholder="Brief subject of your issue"
            />
          </div>
          <div>
            <label className="block text-sm text-gray-400 mb-1">Description</label>
            <textarea 
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded px-4 py-2 text-white focus:outline-none focus:border-red-500 h-32 resize-none"
              required
              placeholder="Please provide details about your issue..."
            />
          </div>
          <button type="submit" className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors shadow-[0_0_15px_rgba(220,38,38,0.5)]">
            Submit Complaint
          </button>
        </form>
      </div>

      <h2 className="text-xl font-semibold mb-4 text-white">My Previous Complaints</h2>
      <div className="space-y-4">
        {complaints.map(c => (
          <div key={c.id} className="glass-panel p-5 border-l-4 border-l-orange-500">
            <div className="flex justify-between items-start mb-2">
              <h3 className="text-lg font-bold text-white">{c.title}</h3>
              <span className={`px-2 py-1 rounded text-xs font-bold ${
                c.status === 'OPEN' ? 'bg-orange-500/20 text-orange-400' :
                c.status === 'RESOLVED' ? 'bg-emerald-500/20 text-emerald-400' :
                'bg-blue-500/20 text-blue-400'
              }`}>
                {c.status}
              </span>
            </div>
            <p className="text-gray-300 text-sm mb-3">{c.description}</p>
            <div className="text-xs text-gray-500">
              Submitted on: {new Date(c.createdAt).toLocaleDateString()}
            </div>
            {c.adminNote && (
              <div className="mt-3 p-3 bg-white/5 rounded-lg border border-white/10">
                <div className="text-xs text-gray-400 mb-1">Admin Response:</div>
                <div className="text-sm text-white">{c.adminNote}</div>
              </div>
            )}
          </div>
        ))}
        {complaints.length === 0 && (
          <div className="text-center py-8 text-gray-400 bg-white/5 rounded-xl">
            You haven't submitted any complaints yet.
          </div>
        )}
      </div>
    </div>
  );
};

export default ComplaintsPage;
