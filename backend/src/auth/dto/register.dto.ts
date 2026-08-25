import { IsEmail, IsOptional, IsString, Length, Matches } from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @Length(8, 72)
  @Matches(/[a-zA-Z]/, { message: 'password must contain a letter' })
  @Matches(/[0-9]/, { message: 'password must contain a digit' })
  password!: string;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  /** Master bootstrap code — promotes the new user to ADMIN if valid. */
  @IsOptional()
  @IsString()
  masterCode?: string;
}
