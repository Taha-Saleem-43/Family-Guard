import type { Member } from '../types';

interface Props {
  member: Member;
  isSelected?: boolean;
  onClick?: () => void;
  showSelf?: boolean;
}

export default function MapPin({ member, isSelected, onClick, showSelf }: Props) {
  const size = isSelected ? 52 : 44;
  const ringSize = isSelected ? 68 : 56;

  return (
    <button
      onClick={onClick}
      className="absolute flex items-center justify-center"
      style={{
        left: `${member.x}%`,
        top: `${member.y}%`,
        transform: 'translate(-50%, -100%)',
        zIndex: isSelected ? 20 : 10,
      }}
    >
      {/* Pulse ring for live/moving */}
      {!member.isStale && (
        <span
          className="absolute rounded-full"
          style={{
            width: ringSize,
            height: ringSize,
            background: member.pinColor + '22',
            border: `2px solid ${member.pinColor}55`,
            transform: 'translate(-50%, -50%) translateY(-8px)',
            left: '50%',
            top: '50%',
          }}
        />
      )}
      {/* Avatar circle */}
      <span
        className={`relative flex items-center justify-center rounded-full font-black text-sm shadow-lg transition-all duration-200 ${member.isMoving ? 'pin-live' : ''}`}
        style={{
          width: size,
          height: size,
          background: member.isStale ? '#94A3B8' : member.pinColor,
          color: '#fff',
          fontSize: size * 0.32,
          boxShadow: isSelected
            ? `0 0 0 3px white, 0 0 0 5px ${member.pinColor}`
            : `0 3px 10px ${member.pinColor}55`,
        }}
      >
        {member.initials}
        {member.isMoving && (
          <span className="absolute -top-1 -right-1 w-4 h-4 bg-warning rounded-full border-2 border-white text-white flex items-center justify-center" style={{ fontSize: 8 }}>
            ›
          </span>
        )}
        {member.battery < 20 && !member.isMoving && (
          <span className="absolute -top-1 -right-1 w-4 h-4 bg-danger rounded-full border-2 border-white text-white flex items-center justify-center" style={{ fontSize: 7 }}>
            !
          </span>
        )}
      </span>
      {/* Pin tail */}
      <span
        className="absolute"
        style={{
          bottom: -6,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 0,
          height: 0,
          borderLeft: '7px solid transparent',
          borderRight: '7px solid transparent',
          borderTop: `8px solid ${member.isStale ? '#94A3B8' : member.pinColor}`,
        }}
      />
      {/* Name label */}
      {(isSelected || showSelf) && (
        <span
          className="absolute whitespace-nowrap text-xs font-bold px-2 py-0.5 rounded-full shadow"
          style={{
            background: member.pinColor,
            color: '#fff',
            bottom: -22,
            left: '50%',
            transform: 'translateX(-50%)',
            fontSize: 11,
          }}
        >
          {member.name.split(' ')[0]}
        </span>
      )}
    </button>
  );
}
