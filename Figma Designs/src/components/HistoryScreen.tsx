import { useState } from 'react';

const DAYS = ['Today', '7 days', '30 days'];

const STOPS = [
  { time: '8:02 AM', place: 'Lincoln High School', address: '890 Lincoln Ave', duration: 'Still here', icon: '🏫', isArrival: true },
  { time: '7:41 AM', place: 'On the move', address: 'Oak Park → Lincoln Ave', duration: '21 min', icon: '🚶', isArrival: false },
  { time: '7:28 AM', place: 'Home', address: '142 Maple Street', duration: '13 min', icon: '🏠', isArrival: false },
  { time: '7:00 AM', place: 'Home (overnight)', address: '142 Maple Street', duration: '7h 28m', icon: '🌙', isArrival: true },
];

const MEMBERS = [
  { id: 'emma', name: 'Emma', initials: 'EM', color: '#2563EB' },
  { id: 'jake', name: 'Jake', initials: 'JK', color: '#D97706' },
];

export default function HistoryScreen() {
  const [activeDay, setActiveDay] = useState(0);
  const [activeMember, setActiveMember] = useState('emma');
  const [view, setView] = useState<'list' | 'map'>('list');

  return (
    <div className="flex flex-col h-full bg-bg">
      {/* Header */}
      <div className="px-5 pt-12 pb-4 bg-bg">
        <h1 className="text-2xl font-black text-text mb-4">Location History</h1>

        {/* Member picker */}
        <div className="flex gap-2 mb-4">
          {MEMBERS.map(m => (
            <button
              key={m.id}
              onClick={() => setActiveMember(m.id)}
              className="flex items-center gap-2 px-3 py-2 rounded-full font-bold text-sm transition-all"
              style={{
                background: activeMember === m.id ? m.color : '#EFF6FF',
                color: activeMember === m.id ? '#fff' : m.color,
              }}
            >
              <span
                className="w-6 h-6 rounded-full flex items-center justify-center text-xs text-white font-black"
                style={{ background: m.color + (activeMember === m.id ? '' : '55') }}
              >
                {m.initials}
              </span>
              {m.name}
            </button>
          ))}
        </div>

        {/* Day range */}
        <div className="bg-white rounded-2xl p-1 flex gap-1 shadow-sm">
          {DAYS.map((d, i) => (
            <button
              key={d}
              onClick={() => setActiveDay(i)}
              className="flex-1 py-2 rounded-xl font-bold text-sm transition-all"
              style={{
                background: activeDay === i ? '#3B82F6' : 'transparent',
                color: activeDay === i ? '#fff' : '#64748B',
              }}
            >
              {d}
            </button>
          ))}
        </div>
      </div>

      {/* Map strip (if map view) */}
      {view === 'map' && (
        <div className="mx-5 mb-3 h-44 bg-map rounded-2xl overflow-hidden relative shadow-sm">
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-muted text-sm font-semibold">Route polyline for {activeDay === 0 ? 'today' : DAYS[activeDay]}</div>
          </div>
          {/* Simple polyline illustration */}
          <svg viewBox="0 0 300 180" className="absolute inset-0 w-full h-full opacity-60">
            <polyline
              points="40,140 80,120 120,90 160,70 200,60 240,50"
              fill="none"
              stroke="#2563EB"
              strokeWidth="3"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeDasharray="0"
            />
            {[
              [40, 140], [240, 50]
            ].map(([x, y], i) => (
              <circle key={i} cx={x} cy={y} r="6" fill={i === 0 ? '#16A34A' : '#2563EB'} />
            ))}
          </svg>
        </div>
      )}

      {/* View toggle */}
      <div className="px-5 flex items-center justify-between mb-3">
        <span className="text-text font-black text-sm">{activeDay === 0 ? "Today's stops" : `Stops (${DAYS[activeDay]})`}</span>
        <div className="flex bg-white rounded-xl p-1 shadow-sm">
          <button
            onClick={() => setView('list')}
            className="px-3 py-1.5 rounded-lg text-xs font-bold transition-all"
            style={{ background: view === 'list' ? '#3B82F6' : 'transparent', color: view === 'list' ? '#fff' : '#64748B' }}
          >
            List
          </button>
          <button
            onClick={() => setView('map')}
            className="px-3 py-1.5 rounded-lg text-xs font-bold transition-all"
            style={{ background: view === 'map' ? '#3B82F6' : 'transparent', color: view === 'map' ? '#fff' : '#64748B' }}
          >
            Map
          </button>
        </div>
      </div>

      {/* Stops list */}
      <div className="flex-1 overflow-y-auto px-5 pb-6">
        {STOPS.map((stop, i) => (
          <div key={i} className="flex gap-3 mb-0">
            {/* Timeline line */}
            <div className="flex flex-col items-center flex-shrink-0">
              <div className="w-9 h-9 rounded-full bg-white border-2 border-border flex items-center justify-center text-base shadow-sm mt-1">
                {stop.icon}
              </div>
              {i < STOPS.length - 1 && <div className="w-0.5 flex-1 bg-border mt-1 mb-1" />}
            </div>
            {/* Content */}
            <div className="flex-1 pb-4">
              <div className="bg-white rounded-2xl p-4 shadow-sm">
                <div className="flex items-start justify-between mb-1">
                  <div className="font-black text-text text-sm">{stop.place}</div>
                  <div className="text-xs text-muted font-semibold flex-shrink-0 ml-2">{stop.time}</div>
                </div>
                <div className="text-muted text-xs font-medium">{stop.address}</div>
                <div className="mt-2 flex items-center gap-1.5">
                  <span className="text-xs bg-bg px-2 py-0.5 rounded-full text-muted font-semibold">{stop.duration}</span>
                  {stop.isArrival && <span className="text-xs bg-success-light px-2 py-0.5 rounded-full text-success font-semibold">Arrival</span>}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
