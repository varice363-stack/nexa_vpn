import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { randomUUID } from 'crypto';
import { Role } from '@prisma/client';

import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { BannersService } from './banners.service';
import { BannerPlacement, CreateBannerDto } from './dto/create-banner.dto';
import { UpdateBannerDto } from './dto/update-banner.dto';

@Controller('banners')
export class BannersController {
  constructor(private readonly banners: BannersService) {}

  /** Public: active banners, optionally filtered by slot (`?placement=home`). */
  @Public()
  @Get()
  findActive(@Query('placement') placement?: BannerPlacement) {
    return this.banners.findActive(placement);
  }

  @Roles(Role.ADMIN)
  @Get('all')
  findAll() {
    return this.banners.findAll();
  }

  /** Admin: ad performance report (impressions, clicks, CTR). */
  @Roles(Role.ADMIN)
  @Get('stats')
  stats() {
    return this.banners.stats();
  }

  @Roles(Role.ADMIN)
  @Post()
  create(@Body() dto: CreateBannerDto) {
    return this.banners.create(dto);
  }

  @Roles(Role.ADMIN)
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateBannerDto) {
    return this.banners.update(id, dto);
  }

  @Roles(Role.ADMIN)
  @Post(':id/activate')
  activate(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.setActive(id, true);
  }

  @Roles(Role.ADMIN)
  @Post(':id/deactivate')
  deactivate(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.setActive(id, false);
  }

  @Roles(Role.ADMIN)
  @Post(':id/reset-stats')
  resetStats(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.resetStats(id);
  }

  /**
   * Public tracking hooks. Both return 204 with no body: the client fires
   * them in the background and must never wait on, or fail because of,
   * analytics.
   */
  /**
   * Admin: удалить баннер навсегда. В отличие от deactivate убирает строку из
   * панели и вычёркивает картинку из ./uploads - иначе "начальный" баннер
   * нельзя было убрать никуда.
   */
  @Roles(Role.ADMIN)
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.remove(id);
  }

  @Public()
  @Post(':id/impression')
  @HttpCode(HttpStatus.NO_CONTENT)
  trackImpression(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.trackImpression(id);
  }

  @Public()
  @Post(':id/click')
  @HttpCode(HttpStatus.NO_CONTENT)
  trackClick(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.trackClick(id);
  }

  /**
   * Загрузка картинки баннера. Отдаётся тем же `app.useStaticAssets`, что и
   * весь каталог uploads, поэтому:
   *   - размер жёстко ограничен 2 МБ (иначе один баннер съедает диск VPS);
   *   - принимаются только растровые png/jpeg/webp. svg не принимаем
   *     намеренно: svg — это XML, который браузер исполняет, а статика
   *     отдаётся с того же origin, что и API (http://IP:3000/uploads/…).
   *     Разрешить svg = подарить XSS на origin с CORS-креденталами.
   */
  @Roles(Role.ADMIN)
  @Post(':id/upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 2 * 1024 * 1024, files: 1 },
      fileFilter: (_req, file, cb) => {
        const ok = /^(image\/png|image\/jpeg|image\/webp)$/.test(file.mimetype);
        if (!ok) {
          cb(new BadRequestException('Banнер принимает только png, jpeg или webp'), false);
          return;
        }
        cb(null, true);
      },
      storage: diskStorage({
        destination: join(process.cwd(), process.env.UPLOADS_DIR || 'uploads'),
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase();
          const safe = ['.png', '.jpg', '.jpeg', '.webp'].includes(ext) ? ext : '.png';
          cb(null, `${randomUUID()}${safe}`);
        },
      }),
    }),
  )
  upload(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Файл не загружен');
    const url = `/uploads/${file.filename}`;
    return this.banners.setImage(id, url);
  }
}
