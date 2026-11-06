// Copies the page and its fonts into www/, the folder Capacitor ships inside the iOS app.
import { cpSync, mkdirSync, rmSync } from 'node:fs'

rmSync('www', { recursive: true, force: true })
mkdirSync('www')
cpSync('index.html', 'www/index.html')
cpSync('fonts', 'www/fonts', { recursive: true })
console.log('www/ ready')
