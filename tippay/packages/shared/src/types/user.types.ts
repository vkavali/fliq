export enum UserType {
  CUSTOMER = 'CUSTOMER',
  PROVIDER = 'PROVIDER',
  ADMIN = 'ADMIN',
}

export enum UserStatus {
  ACTIVE = 'ACTIVE',
  SUSPENDED = 'SUSPENDED',
  DEACTIVATED = 'DEACTIVATED',
}

export enum KycStatus {
  PENDING = 'PENDING',
  BASIC = 'BASIC',
  FULL = 'FULL',
}

export enum ProviderCategory {
  DELIVERY = 'DELIVERY',
  SALON = 'SALON',
  HOUSEHOLD = 'HOUSEHOLD',
  RESTAURANT = 'RESTAURANT',
  HOTEL = 'HOTEL',
  TRANSPORT = 'TRANSPORT',
  HEALTHCARE = 'HEALTHCARE',
  EDUCATION = 'EDUCATION',
  FITNESS = 'FITNESS',
  OTHER = 'OTHER',
}

export enum PayoutPreference {
  INSTANT = 'INSTANT',
  DAILY_BATCH = 'DAILY_BATCH',
  WEEKLY = 'WEEKLY',
}

export interface UserPublic {
  id: string;
  type: UserType;
  phone: string;
  name: string | null;
  languagePreference: string;
  kycStatus: KycStatus;
  status: UserStatus;
}

export interface ProviderPublic {
  id: string;
  displayName: string | null;
  bio: string | null;
  avatarUrl: string | null;
  category: ProviderCategory;
  ratingAverage: number | null;
  totalTipsReceived: number;
  qrCodeUrl: string | null;
}
