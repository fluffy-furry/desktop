import { describe, it } from 'node:test'
import assert from 'node:assert'
import {
  parseAppURL,
  findProtocolURL,
  IOpenRepositoryFromURLAction,
  IOAuthAction,
} from '../../src/lib/parse-app-url'

describe('parseAppURL', () => {
  it('returns unknown by default', () => {
    assert.equal(parseAppURL('').name, 'unknown')
  })

  describe('oauth', () => {
    it('returns right name', () => {
      const result = parseAppURL(
        'x-github-client://oauth?code=18142422&state=e4cd2dea-1567-46aa-8eb2-c7f56e943187'
      )
      assert.equal(result.name, 'oauth')

      const openRepo = result as IOAuthAction
      assert.equal(openRepo.code, '18142422')
    })
  })

  describe('openRepo via HTTPS', () => {
    it('returns right name', () => {
      const result = parseAppURL(
        'github-mac://openRepo/https://github.com/desktop/desktop'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'https://github.com/desktop/desktop')
    })

    it('returns unknown when no remote defined', () => {
      const result = parseAppURL('github-mac://openRepo/')
      assert.equal(result.name, 'unknown')
    })

    it('adds branch name if set', () => {
      const result = parseAppURL(
        'github-mac://openRepo/https://github.com/desktop/desktop?branch=cancel-2fa-flow'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'https://github.com/desktop/desktop')
      assert.equal(openRepo.branch, 'cancel-2fa-flow')
    })

    it('adds pull request ID if found', () => {
      const result = parseAppURL(
        'github-mac://openRepo/https://github.com/octokit/octokit.net?branch=pr%2F1569&pr=1569'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'https://github.com/octokit/octokit.net')
      assert.equal(openRepo.branch, 'pr/1569')
      assert.equal(openRepo.pr, '1569')
    })

    it('returns unknown for unexpected pull request input', () => {
      const result = parseAppURL(
        'github-mac://openRepo/https://github.com/octokit/octokit.net?branch=bar&pr=foo'
      )
      assert.equal(result.name, 'unknown')
    })

    it('returns unknown for invalid branch name', () => {
      // branch=<>
      const result = parseAppURL(
        'github-mac://openRepo/https://github.com/octokit/octokit.net?branch=%3C%3E'
      )
      assert.equal(result.name, 'unknown')
    })

    it('adds file path if found', () => {
      const result = parseAppURL(
        'github-mac://openRepo/https://github.com/octokit/octokit.net?branch=master&filepath=Octokit.Reactive%2FOctokit.Reactive.csproj'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'https://github.com/octokit/octokit.net')
      assert.equal(openRepo.branch, 'master')
      assert.equal(
        openRepo.filepath,
        'Octokit.Reactive/Octokit.Reactive.csproj'
      )
    })
  })

  describe('openRepo via SSH', () => {
    it('returns right name', () => {
      const result = parseAppURL(
        'github-mac://openRepo/git@github.com/desktop/desktop'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'git@github.com/desktop/desktop')
    })

    it('returns unknown when no remote defined', () => {
      const result = parseAppURL('github-mac://openRepo/')
      assert.equal(result.name, 'unknown')
    })

    it('adds branch name if set', () => {
      const result = parseAppURL(
        'github-mac://openRepo/git@github.com/desktop/desktop?branch=cancel-2fa-flow'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'git@github.com/desktop/desktop')
      assert.equal(openRepo.branch, 'cancel-2fa-flow')
    })

    it('adds pull request ID if found', () => {
      const result = parseAppURL(
        'github-mac://openRepo/git@github.com/octokit/octokit.net?branch=pr%2F1569&pr=1569'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'git@github.com/octokit/octokit.net')
      assert.equal(openRepo.branch, 'pr/1569')
      assert.equal(openRepo.pr, '1569')
    })

    it('returns unknown for unexpected pull request input', () => {
      const result = parseAppURL(
        'github-mac://openRepo/git@github.com/octokit/octokit.net?branch=bar&pr=foo'
      )
      assert.equal(result.name, 'unknown')
    })

    it('returns unknown for invalid branch name', () => {
      // branch=<>
      const result = parseAppURL(
        'github-mac://openRepo/git@github.com/octokit/octokit.net?branch=%3C%3E'
      )
      assert.equal(result.name, 'unknown')
    })

    it('adds file path if found', () => {
      const result = parseAppURL(
        'github-mac://openRepo/git@github.com/octokit/octokit.net?branch=master&filepath=Octokit.Reactive%2FOctokit.Reactive.csproj'
      )
      assert.equal(result.name, 'open-repository-from-url')

      const openRepo = result as IOpenRepositoryFromURLAction
      assert.equal(openRepo.url, 'git@github.com/octokit/octokit.net')
      assert.equal(openRepo.branch, 'master')
      assert.equal(
        openRepo.filepath,
        'Octokit.Reactive/Octokit.Reactive.csproj'
      )
    })
  })
})

describe('Linux protocol launch arguments', () => {
  const protocols = new Set([
    'x-github-client',
    'x-github-desktop-auth',
    'x-github-desktop-dev-auth',
  ])

  for (const protocol of [
    'x-github-desktop-auth',
    'x-github-desktop-dev-auth',
  ]) {
    it(`accepts a positional ${protocol} callback after Electron flags`, () => {
      const url = `${protocol}://oauth?code=example&state=expected-state`
      const found = findProtocolURL(
        ['/usr/bin/github-desktop', '--ozone-platform=wayland', url],
        protocols
      )
      assert.equal(found, url)
      assert.deepEqual(parseAppURL(found!), {
        name: 'oauth',
        code: 'example',
        state: 'expected-state',
      })
    })
  }

  it('ignores paths, unregistered schemes, and URL-like flag values', () => {
    assert.equal(
      findProtocolURL(
        [
          '/tmp/repository',
          'https://github.com/desktop/desktop',
          'x-github-desktop-auth-fake://oauth',
          '--url=x-github-desktop-auth://oauth',
        ],
        protocols
      ),
      undefined
    )
  })

  it('preserves Open in Desktop links', () => {
    const url = 'x-github-client://openRepo/https://github.com/desktop/desktop'
    assert.equal(
      findProtocolURL(['/usr/bin/github-desktop', url], protocols),
      url
    )
    assert.equal(parseAppURL(url).name, 'open-repository-from-url')
  })
})
