export enum BusinessType {
  HOTEL = 'HOTEL',
  SALON = 'SALON',
  RESTAURANT = 'RESTAURANT',
  SPA = 'SPA',
  CAFE = 'CAFE',
  RETAIL = 'RETAIL',
  OTHER = 'OTHER',
}

export enum BusinessMemberRole {
  ADMIN = 'ADMIN',
  MANAGER = 'MANAGER',
  STAFF = 'STAFF',
}

export enum InvitationStatus {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  DECLINED = 'DECLINED',
  EXPIRED = 'EXPIRED',
}

export interface BusinessPublic {
  id: string;
  name: string;
  type: BusinessType;
  address: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  logoUrl: string | null;
}
