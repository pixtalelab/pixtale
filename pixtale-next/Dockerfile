# 构建阶段
FROM node:22-alpine AS builder

WORKDIR /app

# better-sqlite3、sharp 原生模块编译依赖
RUN apk add --no-cache python3 make g++

RUN corepack enable && corepack prepare pnpm@11.6.0 --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches

RUN pnpm install --frozen-lockfile

COPY . .

RUN pnpm run build


# 运行阶段
FROM node:22-alpine AS runner

WORKDIR /app

# exiftool-vendored.pl 依赖系统 Perl 才能读 EXIF
RUN apk add --no-cache perl

ENV NODE_ENV=production
ENV PORT=8082

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 8082

CMD ["node", "server.js"]
