import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Role } from '@prisma/client';

import { CurrentUser, SafeUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { AdminUpdateKeyDto } from './dto/admin-update-key.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { AccessActivationService } from './access-activation.service';
import { ProvisioningService } from './provisioning.service';
import { XrayClientSyncService } from './xray-client-sync.service';
import { CreateKeyDto } from './dto/create-key.dto';
import { IssueCodeDto, RedeemCodeDto } from './dto/redeem-code.dto';

@ApiTags('provisioning')
@Controller('provisioning')
export class ProvisioningController {
  constructor(
    private readonly provisioning: ProvisioningService,
    private readonly activation: AccessActivationService,
    private readonly xraySync: XrayClientSyncService,
  ) {}

  /**
   * Админ: состояние «кого пускает ядро».
   * desired = сколько активных ключей в базе, published = сколько уже
   * выложено файлом узлу, nodeClients = сколько ядро реально применил.
   */
  @Roles(Role.ADMIN)
  @Get('xray/status')
  xrayStatus() {
    return this.xraySync.status();
  }

  /** Админ: выложить список ключей узлу немедленно (без ожидания интервала). */
  @Roles(Role.ADMIN)
  @Post('xray/sync')
  xraySyncNow() {
    return this.xraySync.sync();
  }

  /**
   * Public: redeem an access code — no account required.
   *
   * This is the primary entry point of the product: buy a code, type it in,
   * connect. Registration is optional and only adds recovery.
   */
  @Public()
  @Post('redeem')
  redeem(@Body() dto: RedeemCodeDto) {
    return this.activation.redeemToContract(dto.code, dto.deviceId);
  }

  /** Public: check a code without consuming it. */
  @Public()
  @Get('code/:code')
  byCode(@Param('code') code: string) {
    return this.activation.contractByCode(code);
  }

  /** Binds an anonymous key to the signed-in account. */
  @Post('claim')
  claim(@CurrentUser() user: SafeUser, @Body() dto: RedeemCodeDto) {
    return this.activation.claim(dto.code, user.id);
  }

  /** Admin: issue a standalone key that can be sold as a code. */
  @Roles(Role.ADMIN)
  @Post('issue')
  issue(@Body() dto: IssueCodeDto) {
    return this.activation.issue(dto);
  }

  /** Admin: all keys. */
  @Roles(Role.ADMIN)
  @Get('all')
  allKeys() {
    return this.provisioning.allKeys();
  }

  @Get()
  list(@CurrentUser() user: SafeUser) {
    return this.provisioning.list(user);
  }

  /** Current active key (or null). */
  @Get('active')
  active(@CurrentUser() user: SafeUser) {
    return this.provisioning.active(user);
  }

  /**
   * Admin: готовая конфигурация любого ключа (vless:// + QR + код). Объявлено
   * ДО пользовательского ':id': Nest матчит маршруты по порядку, иначе
   * «admin-config» уехал бы в ParseUUIDPipe.
   */
  @Roles(Role.ADMIN)
  @Get('admin-config/:id')
  adminConfig(@Param('id', ParseUUIDPipe) id: string) {
    return this.activation.adminContract(id);
  }

  @Get(':id')
  get(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.provisioning.get(user, id);
  }

  @Post()
  create(@CurrentUser() user: SafeUser, @Body() dto: CreateKeyDto) {
    return this.provisioning.create(user, dto);
  }

  /**
   * Admin: отозвать ключ пользователя. Объявлен ДО пользовательского
   * DELETE ':id' — Nest матчит маршруты в порядке объявления, и без этого
   * «admin-revoke» уехал бы в ParseUUIDPipe.
   */
  @Roles(Role.ADMIN)
  @Delete('admin-revoke/:id')
  async adminRevoke(@Param('id', ParseUUIDPipe) id: string) {
    const res = await this.provisioning.revokeAny(id);
    await this.xraySync.sync().catch(() => null);
    return res;
  }

  /**
   * Admin: изменить ключ (имя, срок, лимит трафика, статус).
   * Объявлен до пользовательского ':id' — Nest матчит маршруты по порядку.
   */
  @Roles(Role.ADMIN)
  @Patch('admin-key/:id')
  async adminUpdate(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AdminUpdateKeyDto,
  ) {
    const res = await this.provisioning.updateAny(id, dto);
    // Снятие/постановка EXPIRED меняет состав ядра — публикуем сразу, не ждём
    // тридцатисекундного тика.
    await this.xraySync.sync().catch(() => null);
    return res;
  }

  /** Admin: удалить ключ навсегда (в отличие от отзыва). */
  @Roles(Role.ADMIN)
  @Delete('admin-key/:id')
  async adminDelete(@Param('id', ParseUUIDPipe) id: string) {
    const res = await this.provisioning.deleteAny(id);
    await this.xraySync.sync().catch(() => null);
    return res;
  }

  @Delete(':id')
  async revoke(@CurrentUser() user: SafeUser, @Param('id', ParseUUIDPipe) id: string) {
    const res = await this.provisioning.revoke(user, id);
    // Отозванный ключ обязан исчезнуть из ядра, иначе «отключить» ничего не отключает.
    await this.xraySync.sync().catch(() => null);
    return res;
  }
}
