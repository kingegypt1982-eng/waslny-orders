DO $$
BEGIN
    CREATE TYPE "AdminNotificationType" AS ENUM ('CAPTAIN_REGISTERED', 'CLIENT_REGISTERED');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "AdminNotification" (
    "id" TEXT NOT NULL,
    "type" "AdminNotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "userId" TEXT,
    "data" JSONB,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminNotification_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "AdminNotification_readAt_createdAt_idx"
ON "AdminNotification"("readAt", "createdAt");

CREATE INDEX IF NOT EXISTS "AdminNotification_createdAt_idx"
ON "AdminNotification"("createdAt");
