import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { isLinuxArm64Binary } from './linux-arm64-process-proxy'

describe('Linux ARM64 process-proxy binary validation', () => {
  it('rejects the x86-64 ELF header shipped under the ARM64 filename', () => {
    const header = Buffer.from(
      '7f454c4602010100000000000000000003003e00',
      'hex'
    )
    assert.equal(isLinuxArm64Binary(header), false)
  })

  it('accepts a 64-bit little-endian AArch64 ELF header', () => {
    const header = Buffer.from(
      '7f454c460201010000000000000000000300b700',
      'hex'
    )
    assert.equal(isLinuxArm64Binary(header), true)
  })

  it('rejects truncated and non-ELF files', () => {
    assert.equal(isLinuxArm64Binary(Buffer.from('7f454c46', 'hex')), false)
    assert.equal(isLinuxArm64Binary(Buffer.alloc(20)), false)
  })
})
