import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';

import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { PrismaModule } from './common/prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ServersModule } from './servers/servers.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { BannersModule } from './banners/banners.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { NotificationsModule } from './notifications/notifications.module';
import { VpnModule } from './vpn/vpn.module';
import { AdminModule } from './admin/admin.module';
import { AccountModule } from './account/account.module';
import { DevicesModule } from './devices/devices.module';
import { ProvisioningModule } from './provisioning/provisioning.module';
import { SessionsModule } from './sessions/sessions.module';
import { BillingModule } from './billing/billing.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    UsersModule,
    ServersModule,
    SubscriptionsModule,
    BannersModule,
    AnalyticsModule,
    NotificationsModule,
    VpnModule,
    AdminModule,
    AccountModule,
    DevicesModule,
    ProvisioningModule,
    SessionsModule,
    BillingModule,
    HealthModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
