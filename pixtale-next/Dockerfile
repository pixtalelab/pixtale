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

# EXIF 读取依赖 Perl，视频封面和时长使用系统 FFmpeg。
RUN apk add --no-cache perl ffmpeg

ENV NODE_ENV=production
ENV PORT=8082
ENV FFMPEG_PATH=/usr/bin/ffmpeg

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 8082

CMD ["node", "server.js"]
