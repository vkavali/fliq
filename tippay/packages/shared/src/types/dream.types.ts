/**
 * Dream — a worker-defined life goal displayed to tippers.
 * Central to the V5 "Donate to Dream" experience.
 */

export enum DreamCategory {
  EDUCATION = 'EDUCATION',
  HEALTH = 'HEALTH',
  FAMILY = 'FAMILY',
  SKILL = 'SKILL',
  EMERGENCY = 'EMERGENCY',
  TRAVEL = 'TRAVEL',
  OTHER = 'OTHER',
}

export interface DreamPublic {
  id: string;
  title: string;
  description: string;
  category: DreamCategory;
  goalAmount: number;  // paise
  currentAmount: number;  // paise
  percentage: number;  // 0-100
  mediaUrl: string | null;
  verified: boolean;
}

export interface DreamImpact {
  title: string;
  previousProgress: number;  // % before this tip
  newProgress: number;  // % after this tip
  goalAmount: number;  // paise
  currentAmount: number;  // paise
}

export interface TipImpact {
  tipId: string;
  workerName: string;
  amount: number;  // paise
  intent: string | null;
  dream: DreamImpact | null;
  message: string;
}
