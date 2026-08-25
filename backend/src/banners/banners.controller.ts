import {
  Body,
  Controller,
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

  /** Local upload (dev). Production: replace with S3/GCS + signed URL. */
  @Roles(Role.ADMIN)
  @Post(':id/upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: join(process.cwd(), process.env.UPLOADS_DIR || 'uploads'),
        filename: (_req, file, cb) => {
          cb(null, `${randomUUID()}${extname(file.originalname)}`);
        },
      }),
    }),
  )
  upload(
    @Param('id', ParseUUIDPipe) id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new Error('No file uploaded');
    const url = `/uploads/${file.filename}`;
    return this.banners.setImage(id, url);
  }
}
