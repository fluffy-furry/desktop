const { _electron: electron } = require('playwright')
const fs = require('node:fs')
const { join, resolve, dirname } = require('node:path')
const { tmpdir } = require('node:os')
const assert = require('node:assert/strict')
const { execFileSync } = require('node:child_process')

;(async () => {
  const executablePath = resolve(
    process.argv[2] || 'dist/github-desktop-linux-x64/github-desktop'
  )
  const appResources = join(dirname(executablePath), 'resources', 'app')
  const testRoot = fs.mkdtempSync(join(tmpdir(), 'desktop-linux-smoke-'))
  const userData = join(testRoot, 'profile')
  const repository = join(testRoot, 'linux-smoke-repository')
  fs.mkdirSync(userData)
  const titleBarStyle = process.env.DESKTOP_SMOKE_TITLE_BAR || 'native'
  const timeout = Number(process.env.DESKTOP_SMOKE_TIMEOUT || 45000)
  fs.writeFileSync(
    join(userData, '.title-bar-config'),
    JSON.stringify({ titleBarStyle })
  )
  fs.mkdirSync(repository)
  const git = (...args) =>
    execFileSync(join(appResources, 'git', 'bin', 'git'), args, {
      cwd: repository,
      env: {
        ...process.env,
        GIT_EXEC_PATH: join(appResources, 'git', 'libexec', 'git-core'),
        GIT_TEMPLATE_DIR: join(
          appResources,
          'git',
          'share',
          'git-core',
          'templates'
        ),
      },
    })
  git('init', '--initial-branch=main')
  git('config', 'user.name', 'Linux Smoke Test')
  git('config', 'user.email', 'smoke@example.invalid')
  fs.writeFileSync(repository + '/README.md', '# Linux smoke fixture\n')
  git('add', 'README.md')
  git('commit', '-m', 'Initial Linux smoke commit')
  const app = await electron.launch({
    executablePath,
    args: [
      ...(process.getuid() === 0 ? ['--no-sandbox'] : []),
      '--disable-gpu',
      `--user-data-dir=${userData}`,
    ],
    timeout,
    env: {
      ...process.env,
      GIT_CONFIG_GLOBAL: join(testRoot, 'gitconfig'),
      SSH_AUTH_SOCK: '',
    },
  })
  try {
    const errors = []
    const page = await app.firstWindow({ timeout })
    page.setDefaultTimeout(timeout)
    page.on('pageerror', error => errors.push(String(error)))
    await page.getByText('Welcome to GitHub Desktop', { exact: true }).waitFor()
    await page
      .getByRole('button', { name: 'Skip this step', exact: true })
      .click()
    await page.getByLabel('Name', { exact: true }).fill('Linux Smoke Test')
    await page
      .getByLabel('Email', { exact: true })
      .fill('smoke@example.invalid')
    await page.getByRole('button', { name: 'Finish', exact: true }).click()
    // Second-instance launch must deliver CLI actions to the existing window.
    execFileSync(executablePath, [
      ...(process.getuid() === 0 ? ['--no-sandbox'] : []),
      '--disable-gpu',
      `--user-data-dir=${userData}`,
      `--cli-open=${repository}`,
    ])
    await page
      .getByRole('button', { name: 'Add repository', exact: true })
      .click()
    try {
      await page
        .getByText('linux-smoke-repository', { exact: true })
        .first()
        .waitFor()
    } catch (error) {
      console.log(
        'Repository open failed UI:',
        await page.locator('body').innerText()
      )
      throw error
    }
    await page.getByRole('tab', { name: 'History', exact: true }).click()
    await page
      .getByText('Initial Linux smoke commit', { exact: true })
      .first()
      .waitFor()
    // Exercise the packaged process-proxy executable, including on ARM64.
    await page.evaluate(() =>
      localStorage.setItem('git-hooks-env-enabled', 'true')
    )
    const hook = join(repository, '.git', 'hooks', 'pre-commit')
    fs.writeFileSync(
      hook,
      '#!/bin/sh\nprintf "hook passed" > .git/smoke-hook-ran\n'
    )
    fs.chmodSync(hook, 0o755)
    fs.appendFileSync(
      join(repository, 'README.md'),
      '\nEdited through Linux smoke test\n'
    )
    await page.getByRole('tab', { name: 'Changes', exact: true }).click()
    await page
      .locator('#__autocompleting-text-input')
      .fill('Commit from Linux application')
    await page.locator('.commit-button').click()
    await page.getByText('No local changes', { exact: true }).waitFor()
    await page.getByRole('tab', { name: 'History', exact: true }).click()
    await page
      .getByText('Commit from Linux application', { exact: true })
      .first()
      .waitFor()
    assert.equal(
      git('log', '-1', '--format=%s').toString().trim(),
      'Commit from Linux application'
    )
    assert.equal(
      fs.readFileSync(join(repository, '.git', 'smoke-hook-ran'), 'utf8'),
      'hook passed'
    )
    if (process.env.DESKTOP_SMOKE_SCREENSHOT) {
      await page.screenshot({ path: process.env.DESKTOP_SMOKE_SCREENSHOT })
    }
    assert.equal(
      await page.locator('.window-controls').isVisible(),
      titleBarStyle === 'custom'
    )
    const keytar = require(join(appResources, 'keytar.node'))
    await keytar.setPassword(
      'codex-linux-smoke-test',
      'temporary-account',
      'temporary-test-value'
    )
    const stored = await keytar.getPassword(
      'codex-linux-smoke-test',
      'temporary-account'
    )
    await keytar.deletePassword('codex-linux-smoke-test', 'temporary-account')
    const keyring = stored === 'temporary-test-value'
    assert.equal(keyring, true)
    assert.deepEqual(errors, [])
    console.log(
      `Linux Electron smoke passed (${process.arch}, ${titleBarStyle}): welcome, local repository, history, GUI commit with hook proxy, Git, and Secret Service round trip`
    )
  } finally {
    await app.close()
    fs.rmSync(testRoot, { recursive: true, force: true })
  }
})().catch(error => {
  console.error(error)
  process.exitCode = 1
})
