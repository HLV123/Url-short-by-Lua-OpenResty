// API base URL — defaults to same origin (OpenResty proxy)
const API_BASE = '';

export interface ShortenRequest {
  url: string;
  alias?: string;
}

export interface ShortenResponse {
  code: string;
  short_url: string;
  created: number;
}

export interface ClickRecord {
  code: string;
  ip: string;
  ua: string;
  device: string;
  referer: string;
  country: string;
  time: number;
}

export interface StatsResponse {
  code: string;
  url: string;
  created: number;
  total_clicks: number;
  unique_ips: number;
  clicks_by_hour: number[];
  top_countries: { country: string; clicks: number }[];
  device_breakdown: { mobile: number; desktop: number; tablet: number; bot: number };
  top_referers?: { referer: string; clicks: number }[];
}

export async function shortenUrl(data: ShortenRequest): Promise<ShortenResponse> {
  const res = await fetch(`${API_BASE}/api/shorten`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.error || 'Failed to shorten URL');
  }
  return res.json();
}

export async function getStats(code: string): Promise<StatsResponse> {
  const res = await fetch(`${API_BASE}/api/stats/${code}`);
  if (!res.ok) {
    throw new Error('Failed to fetch stats');
  }
  return res.json();
}

export function createSSEConnection(code: string, onMessage: (data: ClickRecord) => void): EventSource {
  const es = new EventSource(`${API_BASE}/api/stream?code=${code}`);
  es.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      onMessage(data);
    } catch (e) {
      console.error('SSE parse error:', e);
    }
  };
  return es;
}

export function formatNumber(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toString();
}

export function timeAgo(timestamp: number): string {
  const seconds = Math.floor(Date.now() / 1000 - timestamp);
  if (seconds < 5) return 'vừa xong';
  if (seconds < 60) return `${seconds}s trước`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m trước`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h trước`;
  const days = Math.floor(hours / 24);
  return `${days} ngày trước`;
}

export function maskIp(ip: string): string {
  const parts = ip.split('.');
  if (parts.length === 4) {
    return `${parts[0]}.${parts[1]}.xx.xx`;
  }
  return ip;
}

export function getCountryFlag(countryCode: string): string {
  const flags: Record<string, string> = {
    VN: '🇻🇳', US: '🇺🇸', JP: '🇯🇵', KR: '🇰🇷', CN: '🇨🇳',
    DE: '🇩🇪', FR: '🇫🇷', GB: '🇬🇧', AU: '🇦🇺', CA: '🇨🇦',
    SG: '🇸🇬', TH: '🇹🇭', IN: '🇮🇳', BR: '🇧🇷', RU: '🇷🇺',
  };
  return flags[countryCode] || '🌍';
}

export function getDeviceIcon(device: string): string {
  const icons: Record<string, string> = {
    mobile: '📱',
    desktop: '💻',
    tablet: '📟',
    bot: '🤖',
  };
  return icons[device] || '🔗';
}
