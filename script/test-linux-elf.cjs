const fs = require('node:fs')
const { join } = require('node:path')

const [architecture, ...paths] = process.argv.slice(2)
const expectedMachine = { x64: 62, amd64: 62, arm64: 183 }[architecture]
if (typeof expectedMachine !== 'number' || paths.length === 0) {
  throw new Error(
    'Usage: node script/test-linux-elf.cjs x64|amd64|arm64 path [path...]'
  )
}

function check(path) {
  const stat = fs.lstatSync(path)
  if (stat.isDirectory()) {
    return fs
      .readdirSync(path)
      .reduce((count, name) => count + check(join(path, name)), 0)
  }
  // Symlinks are package metadata; inspect each real file in the payload once.
  // Never follow an absolute package symlink into the build host's filesystem.
  if (!stat.isFile()) {
    return 0
  }

  const header = Buffer.alloc(20)
  const file = fs.openSync(path, 'r')
  let length
  try {
    length = fs.readSync(file, header, 0, header.length, 0)
  } finally {
    fs.closeSync(file)
  }
  if (!header.subarray(0, 4).equals(Buffer.from([0x7f, 0x45, 0x4c, 0x46]))) {
    return 0
  }
  if (length < 20 || header[4] !== 2 || header[5] !== 1) {
    throw new Error(`Expected a complete little-endian ELF64 header: ${path}`)
  }
  const machine = header.readUInt16LE(18)
  if (machine !== expectedMachine) {
    throw new Error(
      `Wrong ELF architecture (${machine}, expected ${expectedMachine}): ${path}`
    )
  }
  return 1
}

for (const path of paths) {
  const count = check(path)
  if (count === 0) {
    throw new Error(`No ELF binaries found: ${path}`)
  }
  console.log(`Verified ${count} ELF binaries for ${architecture}: ${path}`)
}
