-- CreateEnum
CREATE TYPE "Role" AS ENUM ('USER', 'PREMIUM', 'ADMIN');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'BLOCKED', 'DELETED');

-- CreateEnum
CREATE TYPE "ServerProtocol" AS ENUM ('WIREGUARD', 'OPENVPN', 'IKEV2');

-- CreateEnum
CREATE TYPE "ServerStatus" AS ENUM ('ACTIVE', 'DISABLED');

-- CreateEnum
CREATE TYPE "PlanCode" AS ENUM ('MONTHLY', 'QUARTERLY', 'YEARLY', 'LIFETIME');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('TRIAL', 'ACTIVE', 'PAST_DUE', 'EXPIRED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "PaymentProvider" AS ENUM ('INTERNAL', 'SBP', 'CARD', 'APPLE', 'GOOGLE', 'CRYPTO');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'USER',
    "country" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastLogin" TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VpnServer" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "countryCode" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "ip" TEXT NOT NULL,
    "protocol" "ServerProtocol" NOT NULL DEFAULT 'WIREGUARD',
    "load" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "ping" INTEGER NOT NULL DEFAULT 0,
    "premium" BOOLEAN NOT NULL DEFAULT false,
    "status" "ServerStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VpnServer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SubscriptionPlan" (
    "id" TEXT NOT NULL,
    "code" "PlanCode" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "durationDays" INTEGER NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'USD',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SubscriptionPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Subscription" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "planId" TEXT NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'ACTIVE',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Subscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PaymentTransaction" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "subscriptionId" TEXT,
    "planId" TEXT,
    "provider" "PaymentProvider" NOT NULL,
    "providerPaymentId" TEXT,
    "amount" DECIMAL(10,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'USD',
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PaymentTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Banner" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "imageUrl" TEXT,
    "buttonText" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Banner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ConnectionLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "serverId" TEXT NOT NULL,
    "connectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "disconnectedAt" TIMESTAMP(3),
    "durationSec" INTEGER,
    "trafficMb" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ConnectionLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "type" TEXT NOT NULL DEFAULT 'info',
    "read" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Device" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "platform" TEXT,
    "lastSeenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "Device_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AccessKey" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "deviceId" TEXT,
    "name" TEXT NOT NULL,
    "protocol" TEXT NOT NULL DEFAULT 'VLESS',
    "uuid" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3),
    "lastUsedAt" TIMESTAMP(3),

    CONSTRAINT "AccessKey_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE INDEX "User_status_idx" ON "User"("status");

-- CreateIndex
CREATE UNIQUE INDEX "VpnServer_ip_key" ON "VpnServer"("ip");

-- CreateIndex
CREATE INDEX "VpnServer_status_idx" ON "VpnServer"("status");

-- CreateIndex
CREATE INDEX "VpnServer_country_idx" ON "VpnServer"("country");

-- CreateIndex
CREATE UNIQUE INDEX "SubscriptionPlan_code_key" ON "SubscriptionPlan"("code");

-- CreateIndex
CREATE INDEX "Subscription_userId_status_idx" ON "Subscription"("userId", "status");

-- CreateIndex
CREATE INDEX "Subscription_planId_idx" ON "Subscription"("planId");

-- CreateIndex
CREATE INDEX "PaymentTransaction_userId_idx" ON "PaymentTransaction"("userId");

-- CreateIndex
CREATE INDEX "PaymentTransaction_status_idx" ON "PaymentTransaction"("status");

-- CreateIndex
CREATE UNIQUE INDEX "PaymentTransaction_provider_providerPaymentId_key" ON "PaymentTransaction"("provider", "providerPaymentId");

-- CreateIndex
CREATE INDEX "Banner_active_idx" ON "Banner"("active");

-- CreateIndex
CREATE INDEX "ConnectionLog_userId_connectedAt_idx" ON "ConnectionLog"("userId", "connectedAt");

-- CreateIndex
CREATE INDEX "ConnectionLog_serverId_connectedAt_idx" ON "ConnectionLog"("serverId", "connectedAt");

-- CreateIndex
CREATE INDEX "Notification_userId_read_idx" ON "Notification"("userId", "read");

-- CreateIndex
CREATE INDEX "Notification_createdAt_idx" ON "Notification"("createdAt");

-- CreateIndex
CREATE INDEX "Device_userId_idx" ON "Device"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "AccessKey_uuid_key" ON "AccessKey"("uuid");

-- CreateIndex
CREATE INDEX "AccessKey_userId_status_idx" ON "AccessKey"("userId", "status");

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Subscription" ADD CONSTRAINT "Subscription_planId_fkey" FOREIGN KEY ("planId") REFERENCES "SubscriptionPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PaymentTransaction" ADD CONSTRAINT "PaymentTransaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PaymentTransaction" ADD CONSTRAINT "PaymentTransaction_subscriptionId_fkey" FOREIGN KEY ("subscriptionId") REFERENCES "Subscription"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PaymentTransaction" ADD CONSTRAINT "PaymentTransaction_planId_fkey" FOREIGN KEY ("planId") REFERENCES "SubscriptionPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConnectionLog" ADD CONSTRAINT "ConnectionLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ConnectionLog" ADD CONSTRAINT "ConnectionLog_serverId_fkey" FOREIGN KEY ("serverId") REFERENCES "VpnServer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessKey" ADD CONSTRAINT "AccessKey_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessKey" ADD CONSTRAINT "AccessKey_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE SET NULL ON UPDATE CASCADE;

