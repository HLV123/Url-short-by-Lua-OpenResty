/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />

interface Window {
  initClickChart: (data: number[]) => void;
  renderGeoTable: (countries: { country: string; clicks: number }[], total: number) => void;
  renderDeviceBreakdown: (breakdown: Record<string, number>) => void;
  renderRefererTable: (referers: { referer: string; clicks: number }[], total: number) => void;
}
