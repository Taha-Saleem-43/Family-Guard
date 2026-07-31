import type { Member, Place, AlertEvent } from './types';

export const MEMBERS: Member[] = [
  {
    id: 'parent',
    name: 'Alex (You)',
    initials: 'AJ',
    role: 'parent',
    location: 'Home',
    address: '142 Maple Street',
    lastSeen: 'Now',
    battery: 82,
    pinColor: '#7C3AED',
    textColor: '#FFFFFF',
    x: 48,
    y: 52,
    isMoving: false,
  },
  {
    id: 'emma',
    name: 'Emma',
    initials: 'EM',
    role: 'child',
    location: 'Lincoln High School',
    address: '890 Lincoln Ave',
    lastSeen: 'Now',
    battery: 67,
    pinColor: '#2563EB',
    textColor: '#FFFFFF',
    x: 62,
    y: 35,
    isMoving: false,
  },
  {
    id: 'jake',
    name: 'Jake',
    initials: 'JK',
    role: 'child',
    location: 'On the move',
    address: 'Near Oak Park',
    lastSeen: 'Just now',
    battery: 24,
    pinColor: '#D97706',
    textColor: '#FFFFFF',
    x: 33,
    y: 65,
    isMoving: true,
    speed: 12,
  },
];

export const PLACES: Place[] = [
  { id: 'home', name: 'Home', address: '142 Maple Street', icon: 'home', radius: 150, color: '#16A34A', x: 48, y: 52 },
  { id: 'school', name: 'Lincoln High School', address: '890 Lincoln Ave', icon: 'school', radius: 200, color: '#2563EB', x: 62, y: 35 },
  { id: 'work', name: 'Work — Downtown Office', address: '55 Commerce Blvd', icon: 'work', radius: 100, color: '#7C3AED', x: 72, y: 70 },
];

export const ALERTS: AlertEvent[] = [
  { id: '1', memberId: 'emma', memberName: 'Emma', memberColor: '#2563EB', memberInitials: 'EM', place: 'Lincoln High School', type: 'arrive', time: '8:02 AM', date: 'Today' },
  { id: '2', memberId: 'jake', memberName: 'Jake', memberColor: '#D97706', memberInitials: 'JK', place: 'Home', type: 'leave', time: '7:41 AM', date: 'Today' },
  { id: '3', memberId: 'emma', memberName: 'Emma', memberColor: '#2563EB', memberInitials: 'EM', place: 'Home', type: 'leave', time: '7:28 AM', date: 'Today' },
  { id: '4', memberId: 'jake', memberName: 'Jake', memberColor: '#D97706', memberInitials: 'JK', place: 'Lincoln High School', type: 'arrive', time: '3:44 PM', date: 'Yesterday' },
  { id: '5', memberId: 'emma', memberName: 'Emma', memberColor: '#2563EB', memberInitials: 'EM', place: 'Home', type: 'arrive', time: '5:12 PM', date: 'Yesterday' },
  { id: '6', memberId: 'jake', memberName: 'Jake', memberColor: '#D97706', memberInitials: 'JK', place: 'Home', type: 'arrive', time: '6:30 PM', date: 'Yesterday' },
];
