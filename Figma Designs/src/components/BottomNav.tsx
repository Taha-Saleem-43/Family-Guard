import type { Tab } from '../types';

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'map', label: 'Map', icon: '🗺️' },
  { id: 'history', label: 'History', icon: '📅' },
  { id: 'places', label: 'Places', icon: '📍' },
  { id: 'alerts', label: 'Alerts', icon: '🔔' },
  { id: 'settings', label: 'Settings', icon: '⚙️' },
];

interface Props {
  active: Tab;
  onChange: (t: Tab) => void;
}

export default function BottomNav({ active, onChange }: Props) {
  return (
    <div className="flex bg-white border-t border-border shadow-lg z-30 flex-shrink-0">
      {TABS.map(tab => (
        <button
          key={tab.id}
          onClick={() => onChange(tab.id)}
          className="flex-1 flex flex-col items-center justify-center py-2.5 gap-0.5 transition-all active:scale-90"
          style={{ color: active === tab.id ? '#3B82F6' : '#94A3B8' }}
        >
          <span style={{ fontSize: 20, filter: active === tab.id ? 'none' : 'grayscale(1) opacity(0.5)' }}>
            {tab.icon}
          </span>
          <span className="text-xs font-bold" style={{ fontSize: 10 }}>{tab.label}</span>
          {active === tab.id && (
            <span className="absolute bottom-0 w-1.5 h-1.5 rounded-full bg-primary" style={{ bottom: 4 }} />
          )}
        </button>
      ))}
    </div>
  );
}
