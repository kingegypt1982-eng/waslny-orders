DO $$
BEGIN
    CREATE TYPE "MessageType" AS ENUM ('TEXT', 'IMAGE', 'FILE', 'SYSTEM');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "CaptainProfile"
ADD COLUMN IF NOT EXISTS "fcmToken" TEXT;

ALTER TABLE "Order"
ALTER COLUMN "commission" SET DATA TYPE DECIMAL(5,2);

ALTER TABLE "TopUp"
ALTER COLUMN "feeAmount" SET DATA TYPE DECIMAL(10,2);

CREATE TABLE IF NOT EXISTS "ChatMessage" (
    "id" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "type" "MessageType" NOT NULL DEFAULT 'TEXT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "readBy" TEXT,
    "readAt" TIMESTAMP(3),

    CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "ChatMessage_senderId_createdAt_idx"
ON "ChatMessage"("senderId", "createdAt");

CREATE INDEX IF NOT EXISTS "ChatMessage_receiverId_createdAt_idx"
ON "ChatMessage"("receiverId", "createdAt");

DO $$
BEGIN
    ALTER TABLE "ChatMessage"
    ADD CONSTRAINT "ChatMessage_senderId_fkey"
    FOREIGN KEY ("senderId") REFERENCES "User"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE "ChatMessage"
    ADD CONSTRAINT "ChatMessage_receiverId_fkey"
    FOREIGN KEY ("receiverId") REFERENCES "User"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;