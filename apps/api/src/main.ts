import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/http-exception.filter';
import { assertSecretsAreNotDefaults } from './security/secret-guard';

function parseOrigins(value: string | undefined): string[] {
  return (value ?? '').split(',').map((origin) => origin.trim()).filter(Boolean);
}

async function bootstrap() {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET is not set. Refusing to boot without a signing secret.');
  }
  // Development may run with the documented placeholders; anything else must
  // use its own JWT_SECRET / ADMIN_PASSWORD.
  assertSecretsAreNotDefaults();
  // Kashier test integration: all five are mandatory. The per-payment webhook
  // URL may stay empty in local development (serverWebhook is then omitted),
  // but production refuses to boot without it.
  const KASHIER_TEST_HOST = 'https://test-api.kashier.io';
  const isProduction = process.env.NODE_ENV === 'production';
  for (const key of ['KASHIER_MERCHANT_ID', 'KASHIER_API_KEY', 'KASHIER_SECRET_KEY', 'KASHIER_BASE_URL', 'KASHIER_REDIRECT_URL']) {
    if (!process.env[key]) throw new Error(`${key} is not set. Refusing to boot without Kashier test credentials.`);
  }
  if (!process.env.KASHIER_WEBHOOK_URL && isProduction) {
    throw new Error('KASHIER_WEBHOOK_URL is not set. Refusing to boot production without a webhook destination.');
  }
  if (!isProduction && process.env.KASHIER_BASE_URL !== KASHIER_TEST_HOST) {
    throw new Error('Refusing non-test Kashier host outside production.');
  }
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api/v1');
  app.use(helmet());
  // CORS_ORIGINS takes precedence; CLIENT_ORIGIN is kept as a fallback.
  // An unset value must not break startup: CORS headers are simply disabled
  // instead of falling back to a wildcard origin.
  const configuredOrigins = parseOrigins(process.env.CORS_ORIGINS);
  const origins = configuredOrigins.length
    ? configuredOrigins
    : parseOrigins(process.env.CLIENT_ORIGIN);
  app.enableCors({ origin: origins.length ? origins : false });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
  app.useGlobalFilters(new AllExceptionsFilter());
  const swagger = new DocumentBuilder()
    .setTitle('Wasalny Orders API')
    .setDescription('Ready-shipment delivery platform API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, swagger));
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();
