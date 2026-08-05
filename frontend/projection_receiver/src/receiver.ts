import { EventEmitter } from 'node:events'
import { spawn, type ChildProcess } from 'node:child_process'
import * as net from 'node:net'
import * as path from 'node:path'
import * as readline from 'node:readline'
import { usb } from 'usb'
import { AAStack, TOUCH_ACTION, type VideoCodec } from './stack/index.js'
import { isAccessoryMode } from './stack/aoap/handshake.js'
import { AOAP_LOOPBACK_PORT } from './stack/aoap/constants.js'
import { UsbAoapBridge } from './stack/transport/UsbAoapBridge.js'
import {
  IPC_HOST,
  IPC_PORT,
  MessageParser,
  ReceiverMessage,
  writeMessage
} from './ipc.js'

type Device = USBDevice

const DISPLAY_WIDTH = Number(process.env.AA_DISPLAY_WIDTH ?? 1280)
const DISPLAY_HEIGHT = Number(process.env.AA_DISPLAY_HEIGHT ?? 720)
const PHONE_VENDOR_IDS = new Set([
  0x04e8, // Samsung
  0x12d1, // Huawei
  0x18d1, // Google/accessory mode
  0x22b8, // Motorola
  0x22d9, // Oppo
  0x2717, // Xiaomi
  0x2a70, // OnePlus
  0x2d95 // Vivo
])

type ReceiverTransport = 'wired' | 'wireless'

class AndroidAutoReceiver extends EventEmitter {
  private bridge: UsbAoapBridge | null = null
  private stack: AAStack | null = null
  private loopback: net.Socket | null = null
  private wirelessHelper: ChildProcess | null = null
  private wirelessHelperError: string | null = null
  private transport: ReceiverTransport | null = null
  private starting = false
  private running = false
  private stopping = false
  private readonly audioFormats = new Map<
    number,
    { codec: number; sampleRate: number; channels: number }
  >()

  async start(transport: ReceiverTransport = 'wired'): Promise<void> {
    if (this.starting || (this.running && this.transport === transport)) return
    if (this.bridge || this.stack || this.wirelessHelper) await this.stop()
    this.starting = true
    this.transport = transport
    this.emit(
      'status',
      transport === 'wireless' ? 'discovering' : 'connecting',
      transport === 'wireless'
        ? 'Menyiapkan hotspot dan Bluetooth Android Auto wireless'
        : 'Mencari ponsel Android pada USB'
    )
    try {
      const device = transport === 'wired' ? await this.findPhone() : null
      if (device) {
        this.emit(
          'status',
          'connecting',
          `Memulai Android Open Accessory 0x${device.vendorId.toString(16)}:0x${device.productId.toString(16)}`
        )
      }

      const stack = new AAStack({
        huName: 'SDT Multimedia',
        videoWidth: DISPLAY_WIDTH,
        videoHeight: DISPLAY_HEIGHT,
        videoDpi: 160,
        videoFps: 30,
        pixelAspectRatioE4: 10000,
        displayWidth: DISPLAY_WIDTH,
        displayHeight: DISPLAY_HEIGHT,
        driverPosition: 1,
        wifiSsid: 'SDT Multimedia',
        wifiPassword: '12345678',
        wifiChannel: Number(process.env.AA_WIFI_CHANNEL ?? 149),
        fuelTypes: [1],
        hevcSupported: false,
        vp9Supported: false,
        av1Supported: false,
        clusterEnabled: false,
        clusterWidth: 800,
        clusterHeight: 480,
        clusterTierWidth: 800,
        clusterTierHeight: 480,
        clusterFps: 30,
        clusterDpi: 160,
        disableAudioOutput: false
      })
      this.stack = stack
      stack.setClusterStreamActive(false)
      stack.on('video-codec', (codec: VideoCodec) => this.emit('codec', codec))
      stack.on('video-frame', (frame: Buffer) => this.emit('video', frame))
      stack.on(
        'audio-format',
        (
          _channel: string,
          channelId: number,
          codec: number,
          sampleRate: number,
          channels: number
        ) => {
          this.audioFormats.set(channelId, { codec, sampleRate, channels })
        }
      )
      stack.on(
        'audio-frame',
        (frame: Buffer, _timestamp: bigint, _channel: string, channelId: number) => {
          const defaults =
            channelId === 4
              ? { codec: 1, sampleRate: 48000, channels: 2 }
              : { codec: 1, sampleRate: 16000, channels: 1 }
          this.emit('audio', frame, channelId, this.audioFormats.get(channelId) ?? defaults)
        }
      )
      stack.on('connected', () => {
        this.running = true
        this.emit(
          'status',
          'active',
          this.transport === 'wireless'
            ? 'Android Auto wireless aktif'
            : 'Android Auto aktif'
        )
      })
      stack.on('disconnected', (reason?: string) => {
        this.running = false
        if (this.transport === 'wireless' && !this.stopping) {
          this.emit(
            'status',
            'discovering',
            reason || 'Ponsel terputus; menunggu koneksi wireless kembali'
          )
        } else {
          this.emit('status', 'disconnected', reason || 'Ponsel terputus')
        }
        if (this.transport === 'wired' && !this.stopping) {
          setImmediate(() => {
            void this.stop().catch((error: Error) => this.emit('error', error))
          })
        }
      })
      stack.on('error', (error: Error) => this.emit('error', error))

      if (transport === 'wireless') {
        stack.start()
        this.startWirelessHelper()
        this.emit(
          'status',
          'discovering',
          'Wireless siap; pasangkan Bluetooth ponsel dengan SDT Multimedia'
        )
        return
      }

      if (!device) throw new Error('Ponsel Android USB tidak ditemukan')
      const bridge = new UsbAoapBridge(device, (durationMs) => {
        this.emit('status', 'connecting', `Ponsel berpindah ke mode accessory (${durationMs} ms)`)
      })
      this.bridge = bridge
      bridge.on('error', (error: Error) => this.emit('error', error))
      bridge.once('ready', ({ host, port }: { host: string; port: number }) => {
        this.emit('status', 'connecting', 'USB accessory siap; negosiasi Android Auto')
        const socket = net.createConnection({ host, port, allowHalfOpen: true })
        this.loopback = socket
        socket.setNoDelay(true)
        socket.once('connect', () => stack.attachSocket(socket))
        socket.on('error', (error) => this.emit('error', error))
      })
      await bridge.start(AOAP_LOOPBACK_PORT)
    } finally {
      this.starting = false
    }
  }

  async stop(): Promise<void> {
    if (this.stopping) return
    this.stopping = true
    this.running = false
    this.starting = false
    try {
      try {
        this.stack?.stop()
      } catch {}
      this.stack = null
      try {
        this.loopback?.destroy()
      } catch {}
      this.loopback = null
      const helper = this.wirelessHelper
      this.wirelessHelper = null
      if (helper && !helper.killed) helper.kill('SIGTERM')
      const bridge = this.bridge
      this.bridge = null
      if (bridge) await bridge.stop()
      this.transport = null
      this.emit('status', 'disconnected', 'Android Auto dihentikan')
    } finally {
      this.stopping = false
    }
  }

  private startWirelessHelper(): void {
    this.wirelessHelperError = null
    const helperPath = path.join(__dirname, 'wireless_android_auto.py')
    const helper = spawn('/usr/bin/python3', [helperPath], {
      env: {
        ...process.env,
        AA_WIFI_SSID: process.env.AA_WIFI_SSID ?? 'SDT Multimedia',
        AA_WIFI_PASSWORD: process.env.AA_WIFI_PASSWORD ?? '12345678',
        AA_WIFI_CHANNEL: process.env.AA_WIFI_CHANNEL ?? '149',
        AA_WIRELESS_PORT: process.env.AA_WIRELESS_PORT ?? '5277'
      },
      stdio: ['ignore', 'pipe', 'pipe']
    })
    this.wirelessHelper = helper

    const lines = readline.createInterface({ input: helper.stdout! })
    lines.on('line', (line) => {
      const [prefix, state, ...message] = line.split('\t')
      if (prefix === 'STATUS' && state) {
        const detail = message.join('\t')
        if (state === 'error') this.wirelessHelperError = detail
        this.emit('status', state, detail)
      } else if (line.trim()) {
        console.log(`[wireless] ${line}`)
      }
    })
    helper.stderr?.on('data', (chunk: Buffer) => {
      const message = chunk.toString('utf8').trim()
      if (message) console.warn(`[wireless] ${message}`)
    })
    helper.once('error', (error) => this.emit('error', error))
    helper.once('exit', (code, signal) => {
      lines.close()
      if (this.wirelessHelper === helper) this.wirelessHelper = null
      if (!this.stopping && this.transport === 'wireless' && code !== 0) {
        // The helper reports a useful STATUS error before exiting. Preserve it
        // instead of replacing it with the unhelpful generic "exit 1".
        if (!this.wirelessHelperError) {
          this.emit(
            'error',
            new Error(`Helper wireless berhenti (${signal ?? `exit ${code ?? 'unknown'}`})`)
          )
        }
      }
    })
  }

  touch(x: number, y: number, action: string): void {
    if (!this.stack || !this.running) return
    const nativeAction =
      action === 'down' ? TOUCH_ACTION.DOWN : action === 'up' ? TOUCH_ACTION.UP : TOUCH_ACTION.MOVED
    this.stack.sendTouch(nativeAction, [
      {
        x: Math.round(Math.max(0, Math.min(1, x)) * (DISPLAY_WIDTH - 1)),
        y: Math.round(Math.max(0, Math.min(1, y)) * (DISPLAY_HEIGHT - 1)),
        id: 0
      }
    ])
  }

  private async findPhone(): Promise<Device> {
    const devices = (await usb.getDevices()) as Device[]
    const requestedVid = Number.parseInt(process.env.AA_USB_VID ?? '', 16)
    const requestedPid = Number.parseInt(process.env.AA_USB_PID ?? '', 16)
    const exact = devices.find(
      (device) => device.vendorId === requestedVid && (!Number.isFinite(requestedPid) || device.productId === requestedPid)
    )
    const accessory = devices.find(isAccessoryMode)
    const knownPhone = devices.find((device) => PHONE_VENDOR_IDS.has(device.vendorId))
    const selected = exact ?? accessory ?? knownPhone
    if (!selected) {
      const visible = devices
        .map((device) => `0x${device.vendorId.toString(16)}:0x${device.productId.toString(16)}`)
        .join(', ')
      throw new Error(`Ponsel Android tidak ditemukan. USB terlihat: ${visible || 'tidak ada'}`)
    }
    return selected
  }
}

const receiver = new AndroidAutoReceiver()
let client: net.Socket | null = null

function sendStatus(state: string, message: string): void {
  writeMessage(client, ReceiverMessage.STATUS, JSON.stringify({ state, message }))
  console.log(`[receiver] ${state}: ${message}`)
}

receiver.on('status', sendStatus)
receiver.on('codec', (codec: string) => writeMessage(client, ReceiverMessage.CODEC, codec))
receiver.on('video', (frame: Buffer) => writeMessage(client, ReceiverMessage.VIDEO, frame))
receiver.on(
  'audio',
  (
    frame: Buffer,
    channelId: number,
    format: { codec: number; sampleRate: number; channels: number }
  ) => {
    const header = Buffer.allocUnsafe(7)
    header.writeUInt8(channelId, 0)
    header.writeUInt8(format.codec, 1)
    header.writeUInt32BE(format.sampleRate, 2)
    header.writeUInt8(format.channels, 6)
    writeMessage(client, ReceiverMessage.AUDIO, Buffer.concat([header, frame]))
  }
)
receiver.on('error', (error: Error) => sendStatus('error', error.message))

const server = net.createServer((socket) => {
  client?.destroy()
  client = socket
  const parser = new MessageParser()
  sendStatus('idle', 'Receiver Android Auto kabel dan wireless siap')
  socket.on('data', (chunk) => {
    try {
      for (const message of parser.push(chunk)) {
        if (message.type === ReceiverMessage.START) {
          let transport: ReceiverTransport = 'wired'
          if (message.payload.length > 0) {
            const request = JSON.parse(message.payload.toString('utf8')) as {
              transport?: string
            }
            if (request.transport === 'wireless') transport = 'wireless'
          }
          void receiver.start(transport).catch((error: Error) => sendStatus('error', error.message))
        } else if (message.type === ReceiverMessage.DISCONNECT) {
          void receiver.stop().catch((error: Error) => sendStatus('error', error.message))
        } else if (message.type === ReceiverMessage.TOUCH) {
          const touch = JSON.parse(message.payload.toString('utf8')) as {
            x: number
            y: number
            action: string
          }
          receiver.touch(touch.x, touch.y, touch.action)
        } else if (message.type === ReceiverMessage.PING) {
          sendStatus('idle', 'Receiver Android Auto kabel dan wireless siap')
        }
      }
    } catch (error) {
      sendStatus('error', error instanceof Error ? error.message : String(error))
    }
  })
  socket.once('close', () => {
    if (client === socket) client = null
  })
  socket.on('error', (error) => {
    console.warn(`[receiver] IPC client error: ${error.message}`)
  })
})

server.on('error', (error) => {
  console.error(`[receiver] IPC server error: ${error.message}`)
  process.exitCode = 1
})
server.listen(IPC_PORT, IPC_HOST, () => {
  console.log(`[receiver] listening on ${IPC_HOST}:${IPC_PORT}`)
})

async function shutdown(): Promise<void> {
  server.close()
  await receiver.stop().catch(() => undefined)
  process.exit(0)
}

process.on('SIGINT', () => void shutdown())
process.on('SIGTERM', () => void shutdown())
