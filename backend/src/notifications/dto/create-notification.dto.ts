import { IsArray, IsOptional, IsString, IsUUID, Length, ArrayMaxSize } from 'class-validator';

export class CreateNotificationDto {
  @IsString()
  @Length(2, 120)
  title!: string;

  @IsString()
  @Length(2, 500)
  body!: string;

  @IsOptional()
  @IsString()
  type?: string;

  /** If provided — target users; otherwise broadcast to everyone. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsUUID('4', { each: true })
  userIds?: string[];
}
