// 时间格式化工具
export function pad2(value: number): string {
  return value.toString().padStart(2, '0');
}

export function formatDuration(totalSeconds: number): string {
  const clamped = Math.max(0, Math.floor(totalSeconds));
  const hours = Math.floor(clamped / 3600);
  const minutes = Math.floor((clamped % 3600) / 60);
  const seconds = clamped % 60;
  return `${pad2(hours)}:${pad2(minutes)}:${pad2(seconds)}`;
}

export function formatDuration2(totalSeconds: number): string {
  const clamped = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor((clamped % 3600) / 60);
  const seconds = clamped % 60;
  return `${pad2(minutes)}:${pad2(seconds)}`;
}

interface TempStrength {
  temp: number;
  strength: number;
}
interface DayNight {
  day: TempStrength;
  night: TempStrength;
}
// 预设配置常量
export const PRESETS: Record<string, DayNight> = {
  '智能': { day: { temp: 4700, strength: 30 }, night: { temp: 3400, strength: 30 } },
  '自设': { day: { temp: 5200, strength: 50 }, night: { temp: 4700, strength: 60 } },
  '办公': { day: { temp: 5200, strength: 50 }, night: { temp: 4700, strength: 60 } },
  '影视': { day: { temp: 5600, strength: 45 }, night: { temp: 5200, strength: 55 } },
  '游戏': { day: { temp: 6000, strength: 35 }, night: { temp: 5600, strength: 45 } },
};

export const PREFS_NAME = 'eye_protect_prefs';

export interface RestData {
  times: number;
}