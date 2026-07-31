import { useState } from 'react';
import { PLACES } from '../data';
import type { Place } from '../types';

const ICONS: Record<string, string> = { home: '🏠', school: '🏫', work: '🏢', custom: '📌' };
const COLORS: Record<string, string> = { home: '#16A34A', school: '#2563EB', work: '#7C3AED', custom: '#D97706' };

function PlaceCard({ place, onEdit }: { place: Place; onEdit: () => void }) {
  return (
    <button
      onClick={onEdit}
      className="w-full bg-white rounded-2xl p-4 flex items-center gap-4 shadow-sm active:scale-98 transition-transform"
    >
      <div
        className="w-12 h-12 rounded-2xl flex items-center justify-center text-2xl flex-shrink-0"
        style={{ background: place.color + '18' }}
      >
        {ICONS[place.icon]}
      </div>
      <div className="flex-1 text-left">
        <div className="font-black text-text">{place.name}</div>
        <div className="text-muted text-xs font-medium mt-0.5">{place.address}</div>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {['Emma', 'Jake'].map(m => (
            <span key={m} className="text-xs bg-bg px-2 py-0.5 rounded-full text-muted font-semibold">
              🔔 {m}
            </span>
          ))}
        </div>
      </div>
      <div className="text-border text-2xl">›</div>
    </button>
  );
}

function AddPlaceSheet({ onClose }: { onClose: () => void }) {
  const [name, setName] = useState('');
  const [icon, setIcon] = useState<Place['icon']>('home');
  const [radius, setRadius] = useState(150);

  return (
    <div className="absolute inset-0 z-20 flex flex-col justify-end bg-black/30 animate-fade-in">
      <div className="bg-white rounded-t-3xl shadow-2xl animate-slide-up max-h-[90%] overflow-y-auto">
        <div className="drag-handle mt-3" />
        <div className="px-5 pb-3 flex items-center justify-between">
          <h3 className="font-black text-text text-xl">Add Place</h3>
          <button onClick={onClose} className="w-8 h-8 bg-bg rounded-full flex items-center justify-center text-muted font-bold text-lg">×</button>
        </div>

        {/* Map area */}
        <div className="mx-5 mb-4 h-40 bg-map rounded-2xl overflow-hidden relative">
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="w-16 h-16 rounded-full bg-primary/20 border-2 border-primary/40 flex items-center justify-center">
              <span className="text-2xl">{ICONS[icon]}</span>
            </div>
          </div>
          <div className="absolute bottom-3 right-3 bg-white rounded-xl px-3 py-1.5 text-xs text-muted font-semibold shadow">
            Drag to reposition
          </div>
        </div>

        <div className="px-5 space-y-4 pb-8">
          <div>
            <label className="text-sm font-bold text-muted block mb-1.5">Place name</label>
            <input
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="e.g. Lincoln High School"
              className="w-full bg-bg border-2 border-border rounded-2xl px-4 py-3 text-text font-semibold focus:outline-none focus:border-primary transition-colors"
            />
          </div>

          <div>
            <label className="text-sm font-bold text-muted block mb-2">Icon</label>
            <div className="flex gap-2">
              {(Object.entries(ICONS) as [Place['icon'], string][]).map(([k, emoji]) => (
                <button
                  key={k}
                  onClick={() => setIcon(k)}
                  className="flex-1 py-3 rounded-2xl text-2xl transition-all"
                  style={{
                    background: icon === k ? COLORS[k] + '22' : '#F8FAFC',
                    border: `2px solid ${icon === k ? COLORS[k] : '#E2E8F0'}`,
                  }}
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>

          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-sm font-bold text-muted">Alert radius</label>
              <span className="text-primary font-bold text-sm">{radius}m</span>
            </div>
            <input
              type="range"
              min={50}
              max={500}
              value={radius}
              onChange={e => setRadius(Number(e.target.value))}
              className="w-full accent-primary"
            />
          </div>

          <div>
            <label className="text-sm font-bold text-muted block mb-2">Notify me when</label>
            {['Emma', 'Jake'].map(m => (
              <div key={m} className="flex items-center justify-between py-2.5 border-b border-border">
                <span className="font-semibold text-text text-sm">{m} arrives or leaves</span>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" defaultChecked className="sr-only peer" />
                  <div className="w-11 h-6 bg-border rounded-full peer peer-checked:bg-primary transition-colors after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-5" />
                </label>
              </div>
            ))}
          </div>

          <button
            onClick={onClose}
            className="w-full bg-primary text-white font-bold text-lg py-4 rounded-2xl shadow-lg shadow-blue-200 active:scale-95 transition-transform"
          >
            Save Place
          </button>
        </div>
      </div>
    </div>
  );
}

export default function PlacesScreen() {
  const [showAdd, setShowAdd] = useState(false);

  return (
    <div className="flex flex-col h-full bg-bg relative">
      <div className="px-5 pt-12 pb-4">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-black text-text">Places</h1>
          <button
            onClick={() => setShowAdd(true)}
            className="bg-primary text-white font-bold text-sm px-4 py-2 rounded-full shadow-sm active:scale-95 transition-transform"
          >
            + Add Place
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-5 pb-6 space-y-3">
        {PLACES.map(p => (
          <PlaceCard key={p.id} place={p} onEdit={() => {}} />
        ))}

        {/* Info banner */}
        <div className="bg-primary-light rounded-2xl p-4 flex gap-3 mt-2">
          <span className="text-2xl">💡</span>
          <div>
            <div className="font-bold text-primary text-sm">How Places work</div>
            <div className="text-primary/70 text-xs font-medium mt-0.5">
              When a family member enters or leaves a Place, you'll get an instant notification — even if their phone is locked.
            </div>
          </div>
        </div>
      </div>

      {showAdd && <AddPlaceSheet onClose={() => setShowAdd(false)} />}
    </div>
  );
}
