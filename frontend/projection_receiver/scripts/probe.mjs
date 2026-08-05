import * as net from 'node:net'

const port = Number(process.env.AA_RECEIVER_IPC_PORT ?? 5281)
const timeoutMs = Number(process.env.AA_PROBE_TIMEOUT_MS ?? 30000)

function frame(type, body = '') {
  const payload = Buffer.from(body, 'utf8')
  const header = Buffer.alloc(5)
  header.writeUInt8(type, 0)
  header.writeUInt32BE(payload.length, 1)
  return Buffer.concat([header, payload])
}

let pending = Buffer.alloc(0)
const socket = net.createConnection({ host: '127.0.0.1', port })
socket.once('connect', () => socket.write(frame(0x81)))
socket.on('data', (chunk) => {
  pending = Buffer.concat([pending, chunk])
  while (pending.length >= 5) {
    const type = pending.readUInt8(0)
    const length = pending.readUInt32BE(1)
    if (pending.length < 5 + length) return
    const payload = pending.subarray(5, 5 + length)
    pending = pending.subarray(5 + length)
    if (type === 1) console.log(`[status] ${payload.toString('utf8')}`)
    else if (type === 2) console.log(`[codec] ${payload.toString('utf8')}`)
    else if (type === 3) console.log(`[video] ${payload.length} bytes`)
  }
})
socket.on('error', (error) => {
  console.error(`[probe] ${error.message}`)
  process.exitCode = 1
})

setTimeout(() => {
  socket.write(frame(0x83))
  setTimeout(() => socket.end(), 500)
}, timeoutMs)
