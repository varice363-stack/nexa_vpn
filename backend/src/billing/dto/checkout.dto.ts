import { IsIn, IsOptional, IsUUID, Matches } from 'class-validator';

export class CheckoutDto {
  /** Only the plan id is accepted — the price always comes from the backend. */
  @IsUUID()
  planId!: string;

  /** Сеть для USDT-инвойса. Игнорируется остальными провайдерами. */
  @IsOptional()
  @IsIn(['TRC20', 'BEP20'])
  cryptoNetwork?: 'TRC20' | 'BEP20';
}

/** POST /billing/crypto/submit — покупатель сообщает хэш перевода. */
export class SubmitCryptoHashDto {
  @IsUUID()
  transactionId!: string;

  /** TxID в TRON/BSC — hex или base58, 16..128 символов, только алфавит. */
  @Matches(/^[A-Za-z0-9]{16,128}$/)
  txHash!: string;
}

/** POST /billing/crypto/reject — причина отказа (попадает в чек покупателю). */
export class RejectCryptoDto {
  @Matches(/.{3,300}/)
  reason!: string;
}

/** POST /billing/crypto/approve — необязательная заметка для аудита. */
export class ApproveCryptoDto {
  @Matches(/.{0,300}/)
  note?: string;
}
