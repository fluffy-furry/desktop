import { describe, it } from 'node:test'
import assert from 'node:assert'
import { mkdtemp, rm, writeFile } from 'fs/promises'
import { tmpdir } from 'os'
import { join } from 'path'
import { ChildProcess } from 'child_process'
import {
  convertToFlatpakPath,
  formatPathForFlatpak,
  formatWorkingDirectoryForFlatpak,
  spawn,
  spawnEditor,
} from '../../../src/lib/helpers/linux'

describe('convertToFlatpakPath()', () => {
  if (__LINUX__) {
    it('converts /usr paths', () => {
      const path = '/usr/bin/subl'
      const expectedPath = '/var/run/host/usr/bin/subl'
      assert.equal(convertToFlatpakPath(path), expectedPath)
    })

    it('preserves /opt paths', () => {
      const path = '/opt/slickedit-pro2018/bin/vs'
      assert.equal(convertToFlatpakPath(path), path)
    })

    it('preserves Flatpak editor paths', () => {
      const path = '/var/lib/flatpak/app/com.visualstudio.code'
      assert.equal(convertToFlatpakPath(path), path)
    })
  }

  if (__WIN32__) {
    it('returns same path', () => {
      const path = 'C:\\Windows\\System32\\Notepad.exe'
      assert.equal(convertToFlatpakPath(path), path)
    })
  }

  if (__DARWIN__) {
    it('returns same path', () => {
      const path = '/usr/local/bin/code'
      assert.equal(convertToFlatpakPath(path), path)
    })
  }
})

describe('formatWorkingDirectoryForFlatpak()', () => {
  if (__LINUX__) {
    it('escapes string', () => {
      const path = '/home/test/path with space'
      const expectedPath = '/home/test/path with space'
      assert.equal(formatWorkingDirectoryForFlatpak(path), expectedPath)
    })
    it('returns same path', () => {
      const path = '/home/test/path_wthout_spaces'
      assert.equal(formatWorkingDirectoryForFlatpak(path), path)
    })
  }
})

describe('formatPathForFlatpak()', () => {
  it('removes the system Flatpak app prefix', () => {
    assert.equal(
      formatPathForFlatpak('/var/lib/flatpak/app/com.visualstudio.code'),
      'com.visualstudio.code'
    )
  })

  it('preserves native editor paths', () => {
    assert.equal(formatPathForFlatpak('/usr/bin/code'), '/usr/bin/code')
  })
})

function readOutput(child: ChildProcess): Promise<string[]> {
  return new Promise((resolve, reject) => {
    let output = ''
    child.stdout?.on('data', chunk => (output += chunk.toString()))
    child.on('error', reject)
    child.on('close', code => {
      if (code !== 0) {
        reject(new Error(`Child exited with code ${code}`))
      } else {
        resolve(output.trimEnd().split('\n'))
      }
    })
  })
}

describe('Flatpak host launching', { skip: !__LINUX__ }, () => {
  it('routes shell and editor argv through the host without splitting arguments', async t => {
    const directory = await mkdtemp(join(tmpdir(), 'desktop-flatpak-test-'))
    const oldPath = process.env.PATH
    const oldFlatpakHost = process.env.FLATPAK_HOST
    t.after(async () => {
      if (oldPath === undefined) {
        delete process.env.PATH
      } else {
        process.env.PATH = oldPath
      }
      if (oldFlatpakHost === undefined) {
        delete process.env.FLATPAK_HOST
      } else {
        process.env.FLATPAK_HOST = oldFlatpakHost
      }
      await rm(directory, { recursive: true, force: true })
    })
    await writeFile(
      join(directory, 'flatpak-spawn'),
      '#!/bin/sh\nprintf "%s\\n" "$@"\n',
      { mode: 0o755 }
    )
    process.env.PATH = directory
    process.env.FLATPAK_HOST = '1'
    const args = [
      '--working-directory',
      '/home/test/path with space',
      '--literal=$HOME',
    ]
    assert.deepEqual(await readOutput(spawn('/usr/bin/terminal', args)), [
      '--host',
      '/usr/bin/terminal',
      ...args,
    ])
    assert.deepEqual(
      await readOutput(
        spawnEditor('/var/lib/flatpak/app/com.visualstudio.code', args, {})
      ),
      ['--host', 'com.visualstudio.code', ...args]
    )

    process.env.FLATPAK_HOST = '0'
    assert.deepEqual(
      await readOutput(spawn('/bin/sh', ['-c', 'printf "native\\n"'])),
      ['native']
    )
  })
})
