# Stage 1: Install all dependencies + build
FROM node:20-slim AS builder
RUN corepack enable
WORKDIR /app

# Copy workspace config + all package.jsons first (for layer caching)
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml turbo.json tsconfig.base.json ./
COPY packages/shared/package.json packages/shared/
COPY packages/database/package.json packages/database/
COPY apps/backend/package.json apps/backend/

RUN pnpm install --frozen-lockfile

# Copy all source code
COPY packages/shared/ packages/shared/
COPY packages/database/ packages/database/
COPY apps/backend/ apps/backend/

# Build shared → database → backend
RUN pnpm --filter @fliq/shared build
RUN pnpm --filter @fliq/database build
RUN pnpm --filter @fliq/backend build

# Stage 2: Production image with fresh install
FROM node:20-slim AS runner
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
RUN corepack enable
WORKDIR /app

ENV NODE_ENV=production
ENV APP_ENV=production

# Copy workspace config for production install
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY packages/shared/package.json packages/shared/
COPY packages/database/package.json packages/database/
COPY apps/backend/package.json apps/backend/

# Install production deps (now includes prisma CLI)
RUN pnpm install --prod --frozen-lockfile

# Copy built artifacts
COPY --from=builder /app/packages/shared/dist packages/shared/dist
COPY --from=builder /app/packages/database/dist packages/database/dist
COPY --from=builder /app/packages/database/prisma packages/database/prisma
COPY --from=builder /app/apps/backend/dist apps/backend/dist

# Generate Prisma client
RUN pnpm --filter @fliq/database exec prisma generate

# Copy web app static files
COPY apps/web/public apps/web/public

EXPOSE 3000

# Push schema to DB (creates/updates tables without migrations) then start
CMD echo "=== Prisma db push starting ===" && \
    pnpm --filter @fliq/database exec prisma db push --skip-generate --accept-data-loss 2>&1 && \
    echo "=== Prisma db push completed ===" || \
    echo "=== Prisma db push FAILED (app will start anyway) ===" ; \
    exec node apps/backend/dist/main.js
