import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const isProduction = process.env.NODE_ENV === 'production';
  // In production the credentials must come from the environment: never fall
  // back to a default password there. Locally the defaults below apply.
  const adminEmail = process.env.ADMIN_EMAIL ?? (isProduction ? undefined : 'admin@waslny.com');
  const adminPassword = process.env.ADMIN_PASSWORD ?? (isProduction ? undefined : 'Admin@123');
  if (!adminEmail || !adminPassword) {
    throw new Error('ADMIN_EMAIL and ADMIN_PASSWORD must be set to seed in production.');
  }

  const passwordHash = await bcrypt.hash(adminPassword, 12);

  await prisma.user.upsert({
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

  await prisma.pricingSettings.upsert({
    where: { id: 'default' },
    update: {
      basePrice: 30,
      pricePerKm: 8,
      commissionPercent: 10,
      minimumWalletBalance: 0,
      currency: 'EGP',
      minRadiusKm: 0.5,
      maxRadiusKm: 15,
    },
    create: {
      id: 'default',
      basePrice: 30,
      pricePerKm: 8,
      commissionPercent: 10,
      minimumWalletBalance: 0,
      currency: 'EGP',
      minRadiusKm: 0.5,
      maxRadiusKm: 15,
    },
  });

  console.log(`Seed complete: admin account ${adminEmail} + default pricing`);
}

main()
  .catch((error) => {
    console.error('Seed failed', error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
