const fs = require('node:fs')
const path = require('node:path')

const root = path.resolve(__dirname, '..')
fs.cpSync(path.join(root, 'src', 'protos'), path.join(root, 'dist', 'protos'), {
  recursive: true
})
fs.copyFileSync(
  path.join(root, 'src', 'wireless_android_auto.py'),
  path.join(root, 'dist', 'wireless_android_auto.py')
)
