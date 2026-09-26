import { media } from '@/server/server'

export const runtime = 'nodejs'

const handler = (req: Request) => media.fetch(req)

export const GET = handler
