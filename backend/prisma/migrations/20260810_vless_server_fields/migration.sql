-- AlterTable
ALTER TABLE "VpnServer" ADD COLUMN     "port" INTEGER,
ADD COLUMN     "security" TEXT,
ADD COLUMN     "sni" TEXT,
ADD COLUMN     "transport" TEXT;

