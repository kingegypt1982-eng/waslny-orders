import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

/**
 * Creates an admin account in the production database.
 * Run with: DATABASE_URL=... ADMIN_EMAIL=admin@wasalny.app ADMIN_PASSWORD=Admin@123456 ts-node prisma/create-production-admin.ts
 *
 * DO NOT save DATABASE_URL or ADMIN_PASSWORD in any file.
 */

async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  const adminEmail = process.env.ADMIN_EMAIL ?? 'admin@wasalny.app';
  const adminPassword = process.env.ADMIN_PASSWORD ?? 'Admin@123456';

  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set. Pass it as an environment variable when running this script.');
  }
  if (!adminPassword || !adminPassword.trim()) {
    throw new Error('ADMIN_PASSWORD is not set.');
  }

  // Hash the password with bcrypt (same cost factor as the auth service)
  const passwordHash = await bcrypt.hash(adminPassword, 12);

  const prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
  try {
    const result = await prisma.user.upsert({
      where: { email: adminEmail },
      update: {
        name: 'System Admin',
        passwordHash,
        role: 'ADMIN',
        suspendedAt: null,
        wallet: { upsert: { update: {}, create: { balance: 0, currency: 'EGP' } } },
      },
      create: {
        email: adminEmail,
        name: 'System Admin',
        passwordHash,
        role: 'ADMIN',
        wallet: {
          create: {
            balance: 0,
            currency: 'EGP',
          },
        },
      },
    });
    console.log(`Admin account created/updated: ${result.email} (role: ${result.role})`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error('Failed to create production admin:', error instanceof Error ? error.message : 'unknown error');
  process.exit(1);
});