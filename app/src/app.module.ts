import { Body, Controller, Get, Module, Post, UseGuards } from '@nestjs/common';
import { IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
import { ApiKeyGuard } from './api-key.guard';
import { ReleasesService } from './releases.service';

class CreateReleaseDto {
  @IsString()
  @Length(1, 64)
  @Matches(/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/)
  version!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}

@Controller()
class AppController {
  constructor(private readonly releases: ReleasesService) {}
  @Get('health') health() { return { status: 'ok' }; }
  @Get('version') version() {
    return { version: process.env.APP_VERSION ?? '1.0.0', commitSha: process.env.COMMIT_SHA ?? 'local' };
  }
  @Get('releases') list() { return this.releases.list(); }
  @Post('releases')
  @UseGuards(ApiKeyGuard)
  create(@Body() body: CreateReleaseDto) { return this.releases.create(body.version, body.notes); }
}

@Module({ controllers: [AppController], providers: [ReleasesService, ApiKeyGuard] })
export class AppModule {}
