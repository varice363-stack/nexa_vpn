-- AlterTable
ALTER TABLE "AccessKey" ADD COLUMN "serverId" TEXT;

-- CreateIndex
CREATE INDEX "AccessKey_serverId_idx" ON "AccessKey"("serverId");

-- AddForeignKey
ALTER TABLE "AccessKey" ADD CONSTRAINT "AccessKey_serverId_fkey" FOREIGN KEY ("serverId") REFERENCES "VpnServer"("id") ON DELETE SET NULL ON UPDATE CASCADE;
