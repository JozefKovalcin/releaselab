import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function main() {
  const app = await NestFactory.create(AppModule, { logger: false, bodyParser: true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }));
  app.enableShutdownHooks();
  await app.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
  const address = app.getHttpServer().address();
  if (process.send && address && typeof address !== 'string') process.send({ port: address.port });
}
main().catch(() => { console.error('API startup failed: check configuration'); process.exitCode = 1; });
