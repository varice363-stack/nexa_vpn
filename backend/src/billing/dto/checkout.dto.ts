import { IsUUID } from 'class-validator';

export class CheckoutDto {
  /** Only the plan id is accepted — the price always comes from the backend. */
  @IsUUID()
  planId!: string;
}
