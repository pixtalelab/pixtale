import Database from 'better-sqlite3'
import { drizzle } from 'drizzle-orm/better-sqlite3'
import fs from 'node:fs'
import path from 'path'
import { schema } from '@/server/infra/schema'

// 这个模块负责 SQLite 数据库连接，orm 用于 Drizzle 查询，db 用于原始 SQL。

const dataDir = path.join(process.cwd(), 'data')
fs.mkdirSync(dataDir, { recursive: true })

export const databaseFilePath = path.join(dataDir, 'pixtale.sqlite')
const sqlite = new Database(databaseFilePath)

export const db = sqlite
export const orm = drizzle(sqlite, { schema })
