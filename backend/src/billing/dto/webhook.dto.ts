import { IsOptional, IsString } from 'class-validator';

export class WebhookDto {
  @IsString()
  event!: string; // payment.paid | payment.failed | payment.refunded | payment.cancelled

  @IsOptional()
  @IsString()
  providerPaymentId?: string;

  @IsOptional()
  @IsString()
  transactionId?: string;
}
