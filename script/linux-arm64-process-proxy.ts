import { readFile, copyFile } from 'fs/promises'
import { basename, dirname, join } from 'path'
import { spawnSync } from 'child_process'
import { getProxyCommandPath } from 'process-proxy'

/** Check the ELF header rather than trusting the prebuilt binary's filename. */
export function isLinuxArm64Binary(header: Buffer): boolean {
  return (
    header.length >= 20 &&
    header.subarray(0, 6).equals(Buffer.from([0x7f, 0x45, 0x4c, 0x46, 2, 1])) &&
    header.readUInt16LE(18) === 183
  )
}

export async function ensureLinuxArm64ProcessProxy(): Promise<void> {
  const targetArch = process.env.npm_config_arch || process.arch
  if (process.platform !== 'linux' || targetArch !== 'arm64') {
    return
  }

  const binary = getProxyCommandPath('linux', 'arm64')
  if (isLinuxArm64Binary(await readFile(binary))) {
    return
  }

  // process-proxy 0.6.0 includes an x86-64 ELF named linux-arm64, which its
  // installer trusts and skips rebuilding. Use its bundled, unmodified source
  // with the target compiler instead of shipping that mislabeled file.
  console.log('Rebuilding process-proxy for Linux ARM64…')
  const moduleRoot = dirname(dirname(binary))
  // printenvz already declares and installs node-gyp for its native build.
  const nodeGyp = require.resolve('node-gyp/bin/node-gyp.js', {
    paths: [dirname(require.resolve('printenvz'))],
  })
  const result = spawnSync(
    process.execPath,
    [nodeGyp, 'rebuild', '--arch=arm64'],
    {
      cwd: moduleRoot,
      stdio: 'inherit',
    }
  )
  if (result.status !== 0) {
    throw new Error('Failed to build process-proxy for Linux ARM64')
  }
  const rebuilt = join(moduleRoot, 'build', 'Release', basename(binary))
  if (!isLinuxArm64Binary(await readFile(rebuilt))) {
    throw new Error('Rebuilt process-proxy is not a Linux ARM64 executable')
  }
  await copyFile(rebuilt, binary)
}
