# MOROK VPN — Admin Panel (Next.js production build)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
# Клиентский базовый URL инлайнится в бандл → это build-time аргумент.
# '/api' — same-origin прокси: браузер бьёт в себя, Next переотправляет в бэкенд
# (rewrite в next.config.mjs: /api/* -> ${API_PROXY_ORIGIN}/app-api/*).
ARG NEXT_PUBLIC_API_URL=/api
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/package.json ./
COPY --from=builder /app/package-lock.json ./
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3001
CMD ["sh", "-c", "npx next start -p ${PORT:-3001} -H 0.0.0.0"]
