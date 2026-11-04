'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from './auth';

export function TopBar() {
  const path = usePathname();
  const { user } = useAuth();
  const on = (p: string) => (p === '/' ? path === '/' : path.startsWith(p)) ? 'on' : '';
  return (
    <header className="top">
      <div className="wrap">
        <Link href="/" className="brand"><img src="/logo.jpeg" alt="" />Trail Seek</Link>
        <nav className="links">
          <Link className={on('/')} href="/">Explore</Link>
          <Link className={on('/community')} href="/community">Community</Link>
          <Link className={on('/people')} href="/people">Explorers</Link>
          <Link className={on('/bookings')} href="/bookings">My bookings</Link>
          {user ? <Link className={on('/u/')} href={`/u/${user.id}`}>@{user.username}</Link> : <Link className={on('/login')} href="/login">Log in</Link>}
        </nav>
      </div>
    </header>
  );
}
