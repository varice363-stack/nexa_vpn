import { IsDateString, IsEnum, IsOptional } from 'class-validator';
import { PlanCode } from '@prisma/client';

export class CreateSubscriptionDto {
  @IsEnum(PlanCode)
  planCode!: PlanCode;

  @IsOptional()
  @IsDateString()
  expiresAt?: string;
}
