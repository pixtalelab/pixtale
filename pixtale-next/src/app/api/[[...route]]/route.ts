import { app } from '@/server/server'

export const runtime = 'nodejs'

const handler = (req: Request) => app.fetch(req)

export const GET = handler
export const POST = handler
export const OPTIONS = handler;
