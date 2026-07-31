import type { Place } from '../types';

const ICONS: Record<string, string> = {
  home: '🏠', school: '🏫', work: '🏢', custom: '📌',
};

interface Props {
  place: Place;
}

export default function PlaceMarker({ place }: Props) {
  return (
    <div
      className="absolute pointer-events-none"
      style={{ left: `${place.x}%`, top: `${place.y}%`, transform: 'translate(-50%, -50%)' }}
    >
      {/* Radius ring */}
      <div
        className="absolute rounded-full"
        style={{
          width: place.radius * 0.6,
          height: place.radius * 0.6,
          background: place.color + '18',
          border: `1.5px dashed ${place.color}55`,
          transform: 'translate(-50%, -50%)',
          left: '50%',
          top: '50%',
        }}
      />
      {/* Icon */}
      <div
        className="relative z-10 flex items-center justify-center w-8 h-8 rounded-full border-2 border-white shadow-md"
        style={{ background: place.color + '22', fontSize: 14 }}
      >
        {ICONS[place.icon]}
      </div>
    </div>
  );
}
