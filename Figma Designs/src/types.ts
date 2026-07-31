export type Role = 'parent' | 'child';
export type Tab = 'map' | 'history' | 'places' | 'alerts' | 'settings';
export type SOSState = 'none' | 'countdown' | 'active' | 'received' | 'resolved';

export interface Member {
  id: string;
  name: string;
  initials: string;
  role: Role;
  location: string;
  address: string;
  lastSeen: string;
  battery: number;
  speed?: number;
  pinColor: string;
  textColor: string;
  x: number;
  y: number;
  isMoving?: boolean;
  isStale?: boolean;
}

export interface Place {
  id: string;
  name: string;
  address: string;
  icon: 'home' | 'school' | 'work' | 'custom';
  radius: number;
  color: string;
  x: number;
  y: number;
}

export interface AlertEvent {
  id: string;
  memberId: string;
  memberName: string;
  memberColor: string;
  memberInitials: string;
  place: string;
  type: 'arrive' | 'leave';
  time: string;
  date: string;
}
