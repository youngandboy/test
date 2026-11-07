import { Relation } from './FavorTypes';

/** 人情往来对象（联系人）。 */
export interface Person {
  id: string;
  name: string;
  relation: Relation;
  phone: string;
  note: string;
  createdAt: number;
}

export function emptyPerson(): Person {
  return {
    id: '',
    name: '',
    relation: Relation.OTHER,
    phone: '',
    note: '',
    createdAt: 0
  };
}
