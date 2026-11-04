import type { Metadata } from 'next';
import './globals.css';
import { AuthProvider } from '@/components/auth';
import { TopBar } from '@/components/topbar';

export const metadata: Metadata = {
  title: 'Trail Seek · Thrissur eco-tourism',
  description: 'Book Thrissur forest treks, coracle rides and waterfall visits at Athirappilly, Peechi, Chimmony and Chulannur.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>
          <TopBar />
          <main className="wrap">{children}</main>
          <footer className="wrap">Trail Seek · Explore, plan, go together · Thrissur, Kerala</footer>
        </AuthProvider>
      </body>
    </html>
  );
}
