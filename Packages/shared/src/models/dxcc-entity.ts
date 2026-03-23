export interface DXCCEntity {
  id: number;
  name: string;
  prefix: string;
  continent: string;
  cqZone: number;
  ituZone: number;
  latitude?: number;
  longitude?: number;
  isDeleted: boolean;
}
