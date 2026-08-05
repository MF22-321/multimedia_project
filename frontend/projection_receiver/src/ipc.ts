import type * as net from 'node:net'

export const IPC_PORT = Number(process.env.AA_RECEIVER_IPC_PORT ?? 5281)
export const IPC_HOST = '127.0.0.1'

export const enum ReceiverMessage {
  STATUS = 1,
  CODEC = 2,
  VIDEO = 3,
  AUDIO = 4,
  START = 0x81,
  TOUCH = 0x82,
  DISCONNECT = 0x83,
  PING = 0x84
}

export interface WireMessage {
  type: number
  payload: Buffer
}

export function encodeMessage(type: number, payload: Buffer | string): Buffer {
  const body = typeof payload === 'string' ? Buffer.from(payload, 'utf8') : payload
  const header = Buffer.allocUnsafe(5)
  header.writeUInt8(type, 0)
  header.writeUInt32BE(body.length, 1)
  return Buffer.concat([header, body])
}

export function writeMessage(socket: net.Socket | null, type: number, payload: Buffer | string): void {
  if (!socket || socket.destroyed || !socket.writable) return
  const body = typeof payload === 'string' ? Buffer.from(payload, 'utf8') : payload
  const header = Buffer.allocUnsafe(5)
  header.writeUInt8(type, 0)
  header.writeUInt32BE(body.length, 1)
  // Header and payload stay ordered in the TCP stream. Corking lets Node issue
  // one vectored write without copying every H.264/PCM payload into a new
  // Buffer first.
  socket.cork()
  socket.write(header)
  socket.write(body)
  socket.uncork()
}

export class MessageParser {
  private pending: Buffer<ArrayBufferLike> = Buffer.alloc(0)

  push(chunk: Buffer): WireMessage[] {
    this.pending = this.pending.length === 0 ? chunk : Buffer.concat([this.pending, chunk])
    const messages: WireMessage[] = []
    while (this.pending.length >= 5) {
      const length = this.pending.readUInt32BE(1)
      if (length > 64 * 1024 * 1024) throw new Error(`IPC message too large: ${length}`)
      if (this.pending.length < 5 + length) break
      messages.push({ type: this.pending.readUInt8(0), payload: this.pending.subarray(5, 5 + length) })
      this.pending = this.pending.subarray(5 + length)
    }
    return messages
  }
}
