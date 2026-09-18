// Adapted from Brendan Forster (Shiftkey) and the shiftkey/desktop contributors.
// https://github.com/shiftkey/desktop/blob/release-3.4.13-linux1/script/package-electron-builder.ts
/* eslint-disable no-sync */

import { join } from 'path'
import { spawnSync } from 'child_process'
import { access, rename } from 'fs/promises'

import { getVersion } from '../app/package-info'
import { getDistArchitecture, getDistPath, getDistRoot } from './dist-info'

export async function packageElectronBuilder(): Promise<string> {
  const architecture = getDistArchitecture()
  const result = spawnSync(
    process.execPath,
    [
      require.resolve('electron-builder/cli.js'),
      'build',
      '--prepackaged',
      getDistPath(),
      `--${architecture}`,
      '--config',
      join(__dirname, 'electron-builder-linux.yml'),
      // The legacy ARM64 runtime links against the development-only libz.so.
      // The static toolset runs with the normal runtime libraries instead.
      ...(architecture === 'arm64' ? ['--config.toolsets.appimage=1.0.3'] : []),
      '--publish',
      'never',
    ],
    { stdio: 'inherit' }
  )

  if (result.error !== undefined) {
    throw result.error
  }
  if (result.status !== 0) {
    throw new Error(
      `AppImage packaging failed (${result.signal ?? result.status})`
    )
  }

  const installer = join(
    getDistRoot(),
    `GitHubDesktop-linux-${architecture}-${getVersion()}-linux1.AppImage`
  )
  if (architecture === 'x64') {
    // electron-builder uses x86_64 for AppImages; keep our CI artifact names.
    await rename(
      join(
        getDistRoot(),
        `GitHubDesktop-linux-x86_64-${getVersion()}-linux1.AppImage`
      ),
      installer
    )
  }
  await access(installer)
  return installer
}
