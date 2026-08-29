-- AlterTable: add unique deviceId column for auto-registered devices
ALTER TABLE "User" ADD COLUMN "deviceId" TEXT;

-- CreateIndex: unique constraint on deviceId
CREATE UNIQUE INDEX "User_deviceId_key" ON "User"("deviceId");
