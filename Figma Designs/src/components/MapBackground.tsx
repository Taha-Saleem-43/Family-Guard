export default function MapBackground() {
  return (
    <svg
      viewBox="0 0 390 700"
      className="absolute inset-0 w-full h-full"
      style={{ background: '#E8EDF5' }}
    >
      {/* Parks / green areas */}
      <rect x="20" y="20" width="120" height="90" rx="8" fill="#C8E6C9" opacity="0.8" />
      <rect x="200" y="180" width="80" height="60" rx="6" fill="#C8E6C9" opacity="0.8" />
      <rect x="300" y="400" width="70" height="90" rx="6" fill="#C8E6C9" opacity="0.8" />
      <rect x="30" y="450" width="100" height="80" rx="6" fill="#C8E6C9" opacity="0.7" />
      <rect x="150" y="550" width="90" height="70" rx="6" fill="#C8E6C9" opacity="0.7" />

      {/* Water */}
      <ellipse cx="320" cy="150" rx="50" ry="35" fill="#B3E5FC" opacity="0.7" />

      {/* Main roads (wider, slightly yellow-tinted) */}
      {/* Horizontal main road */}
      <rect x="0" y="240" width="390" height="18" fill="#F5F0E0" />
      <line x1="0" y1="249" x2="390" y2="249" stroke="#E8E0C8" strokeWidth="1" strokeDasharray="24,12" />

      {/* Vertical main road */}
      <rect x="178" y="0" width="18" height="700" fill="#F5F0E0" />
      <line x1="187" y1="0" x2="187" y2="700" stroke="#E8E0C8" strokeWidth="1" strokeDasharray="24,12" />

      {/* Secondary roads */}
      <rect x="0" y="120" width="390" height="10" fill="#EDEBE0" />
      <rect x="0" y="380" width="390" height="10" fill="#EDEBE0" />
      <rect x="0" y="520" width="390" height="10" fill="#EDEBE0" />
      <rect x="80" y="0" width="10" height="700" fill="#EDEBE0" />
      <rect x="290" y="0" width="10" height="700" fill="#EDEBE0" />

      {/* Smaller streets */}
      <rect x="0" y="60" width="390" height="6" fill="#EEEAE0" />
      <rect x="0" y="320" width="390" height="6" fill="#EEEAE0" />
      <rect x="0" y="460" width="390" height="6" fill="#EEEAE0" />
      <rect x="0" y="600" width="390" height="6" fill="#EEEAE0" />
      <rect x="140" y="0" width="6" height="700" fill="#EEEAE0" />
      <rect x="230" y="0" width="6" height="700" fill="#EEEAE0" />
      <rect x="340" y="0" width="6" height="700" fill="#EEEAE0" />

      {/* City blocks (building footprints in muted blue-gray) */}
      {[
        [90,130,40,30],[140,130,30,30],[20,130,60,30],
        [20,260,50,50],[90,260,40,50],[200,260,60,50],[280,260,30,50],[320,260,30,50],
        [200,135,50,35],[260,130,25,30],[300,130,40,30],
        [90,400,40,35],[20,400,55,35],[200,400,65,35],[290,400,35,35],[340,400,35,35],
        [90,540,40,30],[20,540,60,30],[200,540,50,30],[270,540,45,30],[330,540,35,30],
        [90,630,40,30],[20,630,60,30],[200,630,60,30],[280,630,50,30],
      ].map(([x, y, w, h], i) => (
        <rect key={i} x={x} y={y} width={w} height={h} rx="2" fill="#D4D9E4" opacity="0.7" />
      ))}

      {/* Park labels */}
      <text x="80" y="72" textAnchor="middle" fill="#5A7A5A" fontSize="8" fontFamily="Nunito, sans-serif" fontWeight="600">Oak Park</text>
      <text x="240" y="215" textAnchor="middle" fill="#5A7A5A" fontSize="8" fontFamily="Nunito, sans-serif" fontWeight="600">Garden Sq</text>

      {/* Street name labels */}
      <text x="195" y="237" textAnchor="middle" fill="#9A9080" fontSize="8" fontFamily="Nunito, sans-serif" fontWeight="700">MAPLE AVE</text>
      <text x="80" y="320" fill="#9A9080" fontSize="7" fontFamily="Nunito, sans-serif" fontWeight="700" transform="rotate(-90, 80, 320)">ELM ST</text>
      <text x="300" y="480" fill="#9A9080" fontSize="7" fontFamily="Nunito, sans-serif" fontWeight="700" transform="rotate(-90, 300, 480)">OAK BLVD</text>
    </svg>
  );
}
