import { createServer } from 'node:http'
import sirv from 'sirv'

const port = Number.parseInt(process.env.PORT || '4173', 10)

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be a valid TCP port.')
}

const server = createServer(sirv('dist', { single: true }))

server.listen(port, '0.0.0.0', () => {
  console.info(`Admin static server listening on port ${port}`)
})