// Mirrors the backend Prisma models (foundation contract).

export type Role = 'USER' | 'PREMIUM' | 'ADMIN';
export type UserStatus = 'ACTIVE' | 'BLOCKED';
export type ServerStatus = 'ACTIVE' | 'DISABLED';
export type ServerProtocol = 'WIREGUARD' | 'OPENVPN' | 'IKEV2';
export type SubscriptionPlan = 'MONTHLY' | 'YEARLY' | 'LIFETIME';
export type SubscriptionStatus = 'ACTIVE' | 'EXPIRED' | 'CANCELLED';

export interface User {
  id: string;
  email: string;
  role: Role;
  country: string | null;
  status: UserStatus;
  createdAt: string;
  lastLogin: string | null;
}

export interface VpnServer {
  id: string;
  name: string;
  country: string;
  countryCode: string;
  city: string;
  ip: string;
  protocol: ServerProtocol;
  load: number;
  ping: number;
  premium: boolean;
  status: ServerStatus;
  createdAt: string;
}

export interface Subscription {
  id: string;
  userId: string;
  planId: string;
  plan?: { id: string; code: string; name: string } | null;
  status: SubscriptionStatus;
  startedAt?: string;
  expiresAt: string | null;
  createdAt: string;
  user?: { id: string; email: string };
}

export type BannerPlacement = 'home' | 'premium';

export interface Banner {
  id: string;
  title: string;
  description: string;
  imageUrl: string | null;
  buttonText: string | null;
  targetUrl: string | null;
  placement: BannerPlacement;
  sortOrder: number;
  impressions: number;
  clicks: number;
  active: boolean;
  createdAt: string;
}

/** GET /banners/stats — ad performance for advertisers. */
export interface BannerStats {
  totals: { impressions: number; clicks: number; ctr: number };
  banners: Array<{
    id: string;
    title: string;
    placement: BannerPlacement;
    active: boolean;
    impressions: number;
    clicks: number;
    ctr: number;
  }>;
}

export interface DashboardData {
  users: { total: number; newToday: number; activePremium: number };
  connections: { online: number };
  trafficMb: number;
  servers: { active: number; disabled: number };
}

export interface OverviewData {
  totalUsers: number;
  activePremium: number;
  blockedUsers: number;
  onlineConnections: number;
  trafficMb: number;
  durationSec: number;
  revenueUsd: number;
}

export interface DailyStat {
  day: string;
  users: number;
  connections: number;
  trafficMb: number;
}

export interface PopularServer {
  server: VpnServer | null;
  connections: number;
  trafficMb: number;
  durationSec: number;
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

export interface Plan {
  id: string;
  code: string;
  name: string;
  description: string | null;
  durationDays: number;
  price: number;
  currency: string;
  isActive: boolean;
  createdAt?: string;
}

export type PaymentStatus = 'PENDING' | 'PAID' | 'FAILED' | 'REFUNDED' | 'CANCELLED';

export interface BillingTransaction {
  id: string;
  userId: string;
  subscriptionId: string | null;
  planId: string | null;
  provider: string;
  providerPaymentId: string | null;
  amount: number;
  currency: string;
  status: PaymentStatus;
  idempotencyKey: string | null;
  webhookEvent: string | null;
  webhookProcessedAt: string | null;
  planName?: string | null;
  createdAt: string;
  user?: { id: string; email: string };
}

export interface AdminAccessKey {
  id: string;
  userId: string;
  deviceId: string | null;
  serverId: string | null;
  name: string;
  protocol: string;
  uuid: string;
  status: string;
  createdAt: string;
  expiresAt: string | null;
  lastUsedAt: string | null;
  user?: { id: string; email: string };
  server?: {
    id: string;
    name: string;
    country: string;
    city: string;
    ip: string;
    status: string;
  } | null;
}
