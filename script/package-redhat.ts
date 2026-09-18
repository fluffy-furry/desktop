// Adapted from Brendan Forster (Shiftkey) and the shiftkey/desktop contributors.
// https://github.com/shiftkey/desktop/blob/release-3.4.13-linux1/script/package-redhat.ts
import { promisify } from 'util'
import { dirname, join } from 'path'
import { tmpdir } from 'os'
import { mkdtemp, readFile, rename, rm, writeFile } from 'fs/promises'

import glob = require('glob')
const globPromise = promisify(glob)

import { getVersion } from '../app/package-info'
import { getDistArchitecture, getDistPath, getDistRoot } from './dist-info'

function getArchitecture() {
  return getDistArchitecture() === 'arm64' ? 'aarch64' : 'x86_64'
}

export async function packageRedhat(): Promise<string> {
  if (process.platform !== 'linux') {
    throw new Error('RPM packaging requires Linux')
  }

  // electron-installer-redhat 4 is an ES module; Node 24 supports require(esm).
  const installer = require('electron-installer-redhat').default
  const distRoot = getDistRoot()
  const templateRoot = await mkdtemp(join(tmpdir(), 'github-desktop-rpm-'))
  const specTemplate = join(templateRoot, 'spec.ejs')
  const originalTemplate = join(
    dirname(require.resolve('electron-installer-redhat')),
    '../resources/spec.ejs'
  )
  // Shiftkey's old preun deletes the CLI after the new package's post script.
  // Recreate only our missing link after the entire upgrade transaction.
  await writeFile(
    specTemplate,
    `${await readFile(
      originalTemplate,
      'utf8'
    )}\n%posttrans\n<% print(post) %>\n`
  )
  await installer({
    src: getDistPath(),
    dest: distRoot,
    arch: getArchitecture(),
    name: 'github-desktop',
    bin: 'github-desktop',
    revision: 'linux1',
    // RPM's T0 payload flag uses all available CPUs for XZ compression.
    compressionLevel: '2T0',
    specTemplate,
    desktopTemplate: 'script/resources/deb/desktop.ejs',
    description: 'Simple collaboration from your desktop',
    productDescription:
      'This is the unofficial port of GitHub Desktop for Linux distributions',
    categories: ['Development', 'RevisionControl'],
    homepage: 'https://github.com/fluffy-furry/desktop',
    requires: [
      '(libcurl or libcurl4)',
      '(libsecret or libsecret-1-0)',
      'gnome-keyring',
      'ca-certificates',
      'libasound.so.2()(64bit)',
      'libxkbcommon.so.0()(64bit)',
      'libXss.so.1()(64bit)',
    ],
    icon: {
      '32x32': 'app/static/linux/logos/32x32.png',
      '64x64': 'app/static/linux/logos/64x64.png',
      '128x128': 'app/static/linux/logos/128x128.png',
      '256x256': 'app/static/linux/logos/256x256.png',
      '512x512': 'app/static/linux/logos/512x512.png',
      '1024x1024': 'app/static/linux/logos/1024x1024.png',
    },
    scripts: {
      post: 'script/resources/rpm/post.sh',
      preun: 'script/resources/rpm/preun.sh',
    },
    mimeType: [
      'x-scheme-handler/x-github-client',
      'x-scheme-handler/x-github-desktop-auth',
      'x-scheme-handler/x-github-desktop-dev-auth',
    ],
  }).finally(() => rm(templateRoot, { recursive: true, force: true }))

  const files = await globPromise(`${distRoot}/github-desktop*.rpm`)
  if (files.length !== 1) {
    throw new Error(`Expected one RPM package, found '${files.join(', ')}'`)
  }

  const destination = join(
    distRoot,
    `GitHubDesktop-linux-${getArchitecture()}-${getVersion()}-linux1.rpm`
  )
  await rename(files[0], destination)
  return destination
}
