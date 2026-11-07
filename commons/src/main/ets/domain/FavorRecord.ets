import { FavorType, Occasion } from './FavorTypes';

/** 一笔人情往来。金额始终为正数，收/送由 type 决定。 */
export interface FavorRecord {
  id: string;
  personId: string;
  type: FavorType;
  amount: number;
  occasion: Occasion;
  date: string;
  note: string;
  createdAt: number;
}
